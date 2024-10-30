<?php

$finder = (new PhpCsFixer\Finder())
    ->in([
        __DIR__ . '/src',
        __DIR__ . '/config',
        __DIR__ . '/public',
        __DIR__ . '/tests',
    ]);

return (new PhpCsFixer\Config())
    ->setFinder($finder)
    ->setUsingCache(true)
    ->setRiskyAllowed(true)
    ->setRules([
        '@Symfony' => true,
        '@PHP74Migration' => true,
        'declare_strict_types' => false,
        'phpdoc_summary' => false,
        'phpdoc_to_comment' => false,
        'yoda_style' => false,
        'single_line_throw' => false,
        'phpdoc_align' => ['align' => 'left'],
        'concat_space' => ['spacing' => 'one'],
        'array_push' => true,
        'no_useless_return' => true,
        'operator_linebreak' => true,
        'phpdoc_order' => true,
        'phpdoc_var_annotation_correct_order' => true,
        'return_assignment' => true,
        'simple_to_complex_string_variable' => true,
        'single_line_comment_style' => true,
        'combine_consecutive_unsets' => true,
        'explicit_indirect_variable' => true,
        'explicit_string_variable' => true,
        'method_chaining_indentation' => true,
        'multiline_comment_opening_closing' => true,
        'multiline_whitespace_before_semicolons' => true,
        'align_multiline_comment' => ['comment_type' => 'all_multiline'],
        'array_indentation' => true,
        'combine_consecutive_issets' => true,
        'dir_constant' => true,
        'is_null' => true,
        'logical_operators' => true,
        'function_to_constant' => true,
        'modernize_types_casting' => false,
        'ternary_to_elvis_operator' => true,
        'set_type_to_cast' => true,
        'self_accessor' => true,
        'php_unit_construct' => true,
        'ordered_traits' => true,
        'native_function_invocation' => [
            'include' => ['@compiler_optimized'],
            'scope' => 'all',
            'strict' => true,
        ],
        'nullable_type_declaration_for_default_null_value' => true,
        'class_attributes_separation' => true,
        'no_extra_blank_lines' => true,
        'method_argument_space' => [
            'on_multiline' => 'ensure_fully_multiline',
            'keep_multiple_spaces_after_comma' => false,
        ],
        'single_class_element_per_statement' => true,
        'strict_comparison' => true,
    ]);