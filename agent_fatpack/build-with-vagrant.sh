#!/bin/sh
set -e
CDIR=$(cd $(dirname $0) && pwd)
cd $CDIR
vagrant up
s3cmd -v -P sync RPMS/ s3://kurado-agent/RPMS/
