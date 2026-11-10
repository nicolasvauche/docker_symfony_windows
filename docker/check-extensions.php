<?php

foreach (['intl', 'mbstring', 'pdo_sqlite', 'sqlite3', 'pdo_pgsql', 'pgsql', 'mongodb'] as $extension) {
    if (!extension_loaded($extension)) {
        fwrite(STDERR, "$extension missing\n");
        exit(1);
    }
    echo "$extension OK\n";
}
$db = new PDO('sqlite::memory:');
$db->exec('CREATE TABLE smoke_test (id INTEGER PRIMARY KEY)');
echo "SQLite query OK\n";
