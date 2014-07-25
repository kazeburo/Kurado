# How to fatpack with docker
#
# docker build -t `whoami`/perl-build .
# docker run -v `pwd`/../:/perl-build `whoami`/perl-build
#

FROM centos:centos6

RUN yum install -y make gcc
RUN yum install -y git curl
RUN yum install -y tar bzip2 patch

RUN git clone git://github.com/tokuhirom/plenv.git /usr/share/plenv
RUN git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build
ENV PATH ${PATH}:/usr/share/plenv/bin
ADD plenv_profile.sh /etc/profile.d/plenv.sh
RUN . /etc/profile.d/plenv.sh
RUN plenv install 5.8.5
RUN plenv global 5.8.5
ENV PLENV_VERSION 5.8.5
RUN curl -L http://cpanmin.us/ | plenv exec perl - -n ExtUtils::MakeMaker@6.66
RUN curl -L http://cpanmin.us/ | plenv exec perl - -n App::cpanminus
RUN curl -L http://cpanmin.us/ | plenv exec perl - -n Perl::Strip App::FatPacker
RUN plenv rehash

RUN yum install -y rpm-build

CMD bash -l -c 'cd /fatpack; cpanm -n --installdeps /fatpack/agent_fatpack ; bash agent_fatpack/fatpack.sh'
