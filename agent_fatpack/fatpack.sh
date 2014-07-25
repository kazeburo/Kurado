#!/bin/bash
SRC=bin/kurado_agent
DST=agent_fatpack/SOURCES/kurado_agent
export PLENV_VERSION=5.8.5
export PERL5LIB=`dirname $0`/../lib/

fatpack trace $SRC
perl -nle 'print unless m!^(Cwd\.pm$|File/Spec|List/Util|Scalar/Util)!' fatpacker.trace > fatpacker.trace.tmp
mv fatpacker.trace.tmp fatpacker.trace
fatpack packlists-for `cat fatpacker.trace` >packlists
fatpack tree `cat packlists`

if type perlstrip >/dev/null 2>&1; then
    find fatlib -type f -name '*.pm' | xargs -n1 perlstrip -s
fi

(echo "#!/usr/bin/env perl"; fatpack file; cat $SRC) > $DST
perl -pi -e 's|^#!/usr/bin/perl|#!/usr/bin/env perl|' $DST
chmod +x $DST

echo "%_topdir $(pwd)/agent_fatpack" > $HOME/.rpmmacros
echo "%debug_package %{nil}" >> $HOME/.rpmmacros

cp -af agent_fatpack/SPECS/kurado_agent.spec.tmpl agent_fatpack/SPECS/kurado_agent.spec
D_VER=$(date +%Y%m%d)
D_REL=$(date +%H%M|sed 's/^0//')
sed -i "s/<VERSION>/$D_VER/" agent_fatpack/SPECS/kurado_agent.spec
sed -i "s/<RELEASE>/$D_REL/" agent_fatpack/SPECS/kurado_agent.spec
head agent_fatpack/SPECS/kurado_agent.spec
rpmbuild -bb agent_fatpack/SPECS/kurado_agent.spec
rm -f agent_fatpack/SPECS/kurado_agent.spec
mv agent_fatpack/RPMS/noarch/kurado_agent-$D_VER-$D_REL.noarch.rpm \
     agent_fatpack/RPMS/noarch/kurado_agent-latest.noarch.rpm
