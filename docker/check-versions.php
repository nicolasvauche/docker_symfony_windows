<?php

// Validate the actual runtime, not only the image tag selected by the resolver.
if (PHP_VERSION !== getenv('EXPECTED_PHP_VERSION')) {
    fwrite(STDERR, 'Version PHP inattendue : '.PHP_VERSION.PHP_EOL);
    exit(1);
}
$composer = shell_exec('composer --version --no-ansi');
if (!preg_match('/\bComposer (?:version )?(\d+\.\d+\.\d+)(?=\s|$)/i', $composer, $matches)
    || $matches[1] !== getenv('EXPECTED_COMPOSER_VERSION')) {
    fwrite(STDERR, 'Version Composer inattendue : '.$composer.PHP_EOL);
    exit(1);
}
$franken = shell_exec('frankenphp version');
if (!preg_match('/\bFrankenPHP\s+v?(\d+\.\d+\.\d+)(?=\s|$)/i', $franken, $matches)
    || $matches[1] !== getenv('EXPECTED_FRANKENPHP_VERSION')) {
    fwrite(STDERR, 'Version FrankenPHP inattendue : '.$franken.PHP_EOL);
    exit(1);
}
echo 'Versions PHP, Composer et FrankenPHP verifiees.'.PHP_EOL;
