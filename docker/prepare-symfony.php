<?php

// Pin before resolving dependencies: older patch requests must not install latest.
$version = getenv('EXPECTED_SYMFONY_VERSION');
if (!preg_match('/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/D', $version)) {
    throw new RuntimeException('Version Symfony exacte invalide.');
}
$config = json_decode(file_get_contents('composer.json'), false, 512, JSON_THROW_ON_ERROR);
$config->require->{'symfony/framework-bundle'} = $version;
if (isset($config->{'flex-require'}->{'symfony/framework-bundle'})) {
    $config->{'flex-require'}->{'symfony/framework-bundle'} = $version;
}
file_put_contents('composer.json', json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR)."\n");
