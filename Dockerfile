#syntax=docker/dockerfile:1.4

# The different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/develop/develop-images/multistage-build/#stop-at-a-specific-build-stage
# https://docs.docker.com/compose/compose-file/#target

FROM php:8.3-fpm-alpine AS app_php

WORKDIR /srv

# php extensions installer: https://github.com/mlocati/docker-php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# persistent / runtime deps
RUN apk add --no-cache \
		git \
		make \
		postgresql-dev \
	;

RUN set -eux; \
	install-php-extensions \
		intl \
		zip \
		apcu \
		opcache \
		pdo \
		pdo_pgsql \
		gd \
		exif \
		ftp \
		curl \
	;

# PHP configuration
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY docker/php/conf.d/app.ini $PHP_INI_DIR/conf.d/

# PHP-FPM configuration
COPY docker/php/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
RUN mkdir -p /var/run/php

# Entrypoint
COPY docker/php/entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="${PATH}:/root/.composer/vendor/bin"

COPY --from=composer/composer:2-bin /composer /usr/bin/composer

ARG COMPOSER_GITHUB_TOKEN=""
RUN set -eux; \
	if [ -n "${COMPOSER_GITHUB_TOKEN}" ]; then \
		composer config -g github-oauth.github.com "${COMPOSER_GITHUB_TOKEN}"; \
	fi

# PHP Local security checker
ARG SECURITY_CHECKER_VERSION="2.0.6"
ARG SECURITY_CHECKER_ARCH="linux_amd64"
RUN curl -fL https://github.com/fabpot/local-php-security-checker/releases/download/v${SECURITY_CHECKER_VERSION}/local-php-security-checker_${SECURITY_CHECKER_VERSION}_${SECURITY_CHECKER_ARCH} > /usr/local/bin/local-php-security-checker
RUN chmod +x /usr/local/bin/local-php-security-checker

# Nginx
FROM nginx:1-alpine AS app_nginx

# Copy nginx conf
COPY docker/nginx/*.conf /etc/nginx/
COPY docker/nginx/templates/ /etc/nginx/templates/
