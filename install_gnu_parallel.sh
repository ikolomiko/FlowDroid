#!/usr/bin/env bash

set +e
which parallel 2>/dev/null && echo "GNU Parallel is already installed" && exit 1
set -e

mkdir -p ~/.downloads
cd ~/.downloads
wget https://ftpmirror.gnu.org/parallel/parallel-latest.tar.bz2 -O parallel.tar.bz2
tar xvf parallel.tar.bz2
rm -rf gnu-parallel
mv parallel-* gnu-parallel
cd gnu-parallel
./configure --prefix=$HOME/.local
make
make install

