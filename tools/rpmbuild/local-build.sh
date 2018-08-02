#!/bin/bash

VER=$(cat ../../DESCRIPTION | grep Version: | awk {'print $2'})
NAME=$(cat ../../DESCRIPTION | grep Package: | awk {'print $2'}) 
WORKSPACE=`pwd`

rm -rvf BUILD BUILDROOT RPMS SRPMS SOURCES
mkdir BUILD BUILDROOT RPMS SRPMS SOURCES

pushd ../../
tar cvzf tools/rpmbuild/SOURCES/${NAME}_${VER}.tar.gz --transform "s,^\.,${NAME}," --exclude=tools/rpmbuild --exclude=.git .
popd

cd SPECS
for SPEC in *.spec; do
  time rpmbuild --define "_topdir ${WORKSPACE}" -ba ${SPEC}
done
