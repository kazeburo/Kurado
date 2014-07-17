use strict;
use Test::More;
use Net::EmptyPort qw(empty_port);
use Test::RedisServer;
use Kurado::Storage;
use Kurado::Object::Plugin;
use Kurado::Object::Msg;

my $redis_server;
my $port = empty_port();
eval {
    $redis_server = Test::RedisServer->new(
        conf => { port => $port },
    );
} or plan skip_all => 'redis-server is required to this test';
 
my $s = Kurado::Storage->new( redis => '127.0.0.1:'.$port );

#{plugin=>"test",address=>"127.0.0.1",key=>"test1",value=>"testval1",expires=>180}

my $plugin = Kurado::Object::Plugin->new(
    plugin => "test",
    arguments => [],
);

ok($s->set({
    msg => Kurado::Object::Msg->new(
        plugin => $plugin,
        address => '127.0.0.1',
        key => "test1",
        value => "testval1",
        metrics_type => 'metrics',
        timestamp => time()
    ), 
    expires => 180,
}),"set");

ok($s->set({
    msg => Kurado::Object::Msg->new(
        plugin => $plugin,
        address => '127.0.0.1',
        key => "test2",
        value => "testval2",
        metrics_type => 'metrics',
        timestamp => time()
    ), 
    expires => 2,
}),"set");


is_deeply(
    $s->get_by_plugin({plugin=>$plugin,address=>"127.0.0.1"}),
    { test1 => "testval1", test2 => "testval2" },
    "get_by_plugin"
);

ok($s->remove({
    plugin => $plugin,
    address => '127.0.0.1',
    key => "test1",
}),"remove");

sleep 3;

is_deeply(
    $s->get_by_plugin({plugin=>$plugin,address=>"127.0.0.1"}),
    {},
    "get_by_plugin after remove"
);

done_testing();



