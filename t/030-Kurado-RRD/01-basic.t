use strict;
use Test::More;
use File::Temp qw/tempdir/;
use File::Zglob;
use File::Spec;
use Kurado::RRD;
use Kurado::Object::Plugin;

my $tempdir = tempdir( CLEANUP => 1 );

my $rrd = Kurado::RRD->new(data_dir => $tempdir );
ok($rrd->update(
    plugin => Kurado::Object::Plugin->new(
        plugin => "test",
        arguments => [],
    ),
    address => '127.0.0.1',
    key => "test1.gauge",
    value => "12345",
    timestamp => time,
),'update');

my @files = zglob(File::Spec->catfile($tempdir,'**/*.gauge.rrd'));
ok(scalar @files);

done_testing;


