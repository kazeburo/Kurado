requires 'Alien::RRDtool', '0.05';
requires 'Kossy',          '0.37';
requires 'HTTP::Date';
requires 'Log::Minimal',   '0.16';
requires 'List::MoreUtils';
requires 'Starlet',        '0.21';
requires 'HTTP::Parser::XS', '0.16';
requires 'Proclet',        '0.31';
requires 'Plack::Builder::Conditionals',        '0.03';
requires 'JSON', 2;
requires "JSON::XS";
requires 'Class::Accessor::Lite';
requires 'URI::Escape';

requires 'boolean';
requires 'Cwd::Guard';
requires 'TOML';
requires 'Mouse';
requires 'YAML::XS';
requires 'Data::Validator';
requires 'Redis::Fast';
requires 'Parallel::Prefork';
requires 'File::Zglob';
requires 'Unicode::EastAsianWidth';
requires 'Text::MicroTemplate::DataSection';
requires 'Text::MicroTemplate::Extended';

on 'test' => sub {
    requires 'Test::More',     '0.96';
    requires 'Test::RedisServer';
};


