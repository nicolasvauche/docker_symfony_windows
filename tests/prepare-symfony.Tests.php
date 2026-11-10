<?php

// Run with PHP in the base image; verifies Composer object types and exact pins.
$prepareScript = $argv[1] ?? '/usr/local/lib/prepare-symfony.php';
$previousDirectory = getcwd();
$testDirectory = sys_get_temp_dir().'/symfony-pin-test-'.bin2hex(random_bytes(8));
mkdir($testDirectory);
chdir($testDirectory);
putenv('EXPECTED_SYMFONY_VERSION=7.4.22');
try {
    foreach ([false, true] as $hasFlexRequire) {
        $fixture = (object) [
            'require' => (object) ['php' => '>=8.2', 'symfony/flex' => '^2'],
            'require-dev' => new stdClass(),
            'extra' => (object) ['symfony' => (object) ['require' => '7.4.*']],
        ];
        if ($hasFlexRequire) {
            $fixture->{'flex-require'} = (object) ['symfony/framework-bundle' => '*', 'symfony/console' => '*'];
        }
        file_put_contents('composer.json', json_encode($fixture, JSON_THROW_ON_ERROR));
        include $prepareScript;
        $actual = json_decode(file_get_contents('composer.json'), false, 512, JSON_THROW_ON_ERROR);
        if (!$actual->{'require-dev'} instanceof stdClass
            || $actual->require->{'symfony/framework-bundle'} !== '7.4.22'
            || $actual->require->php !== '>=8.2'
            || $actual->extra->symfony->require !== '7.4.*'
            || ($hasFlexRequire && $actual->{'flex-require'}->{'symfony/framework-bundle'} !== '7.4.22')) {
            throw new RuntimeException('Composer pin or JSON structure regression.');
        }
    }
    echo "PASS: exact Symfony pin, empty JSON objects preserved, legacy and flex-require skeletons.\n";
} finally {
    unlink('composer.json');
    chdir($previousDirectory);
    rmdir($testDirectory);
}
