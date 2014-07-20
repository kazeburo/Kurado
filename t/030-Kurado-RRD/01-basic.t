use strict;
use Test::More;
use File::Temp qw/tempdir/;
use File::Zglob;
use File::Spec;
use Kurado::RRD;
use Kurado::Object::Plugin;
use Kurado::Object::Msg;

my $tempdir = tempdir( CLEANUP => 1 );

my $rrd = Kurado::RRD->new(data_dir => $tempdir );
my $msg = Kurado::Object::Msg->new(
    plugin => Kurado::Object::Plugin->new(
        plugin => "test",
        arguments => [],
    ),
    key => "test1.gauge",
    value => "12345",
    timestamp => time,
    address => '127.0.0.1',
    metrics_type => 'metrics'
);
ok($rrd->update(
    msg => $msg,
),'update');

my @files = zglob(File::Spec->catfile($tempdir,'**/*.gauge.rrd'));
ok(scalar @files);

done_testing;


