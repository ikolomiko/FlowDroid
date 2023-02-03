#!/usr/bin/env bash
set -e

usage() {
  echo "usage: ./stats.sh <results dir>"
  exit -1
}

num_of_libs() {
  echo "$1" | cut -d"/" -f2 | sort -u | wc -l
}

[[ -d "$1" ]] || usage

leaks_versions=$(grep 'Found [^0].* leaks' -l "$1"/*/*/flowdroid-log.txt)
leaks_libs=$(num_of_libs "$leaks_versions")
leaks_versions=$(echo "$leaks_versions" | wc -l)

analyzed_versions=$(find "$1" -name "flowdroid-results.xml")
analyzed_libs=$(num_of_libs "$analyzed_versions")
analyzed_versions=$(echo "$analyzed_versions" | wc -l)

total_versions=$(find "$1" -mindepth 2 -maxdepth 2 | wc -l)
total_libs=$(find "$1" -mindepth 1 -maxdepth 1 | wc -l)

echo "Analyzed $analyzed_versions/$total_versions libraries with versions"
echo "$(($total_versions - $analyzed_versions)) of them could not be analyzed"
echo
echo "Analyzed $analyzed_libs/$total_libs libraries without versions"
echo "$(($total_libs - $analyzed_libs)) of them could not be analyzed"
echo
echo "Found leaks in $leaks_versions/$analyzed_versions libraries with versions"
echo "Found leaks in $leaks_libs/$analyzed_libs libraries without versions"

