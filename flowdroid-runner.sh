#!/usr/bin/env bash

OUTPUT_ROOT="$1"
FAIL=0

if [ -z $1 ]; then
    echo "usage: bash flowdroid-runner.sh <output dir>"
    exit 1
fi

mkdir -p $OUTPUT_ROOT
OUTPUT_ROOT=$(realpath $OUTPUT_ROOT)

LIBS_ROOT="../libsec-scraper/updated-libs"

start_analysis() {
#LIBRARY_ID="$1" # GROUP_ID+ARTIFACT_ID+VERSION
#INPUT_FILE="$2" # <file>.aar || <file>.jar
#OUTPUT_PATH="$3" # <output directory path>

 ./flowdroid-libsec-wrapper.sh $1 $2 $3
}

for subfolder in $(find $LIBS_ROOT -mindepth 1 -maxdepth 1 -type d); do
    base_id=$(basename $subfolder)
    for file in $(find $subfolder -mindepth 1 -maxdepth 1 -type f -name "*.aar" -or -name "*.jar"); do
        filename=$(basename $file)
        version="${filename%.*}"
        library_id="$base_id+$version"
        input_file=$(realpath $file)
        mkdir -p $OUTPUT_ROOT/$base_id/$version

        start_analysis $library_id $input_file $(realpath $OUTPUT_ROOT/$base_id/$version) &

        for job in $(jobs -p); do
            wait $job || let "FAIL+=1"
        done
    done
done

echo "Fails: $FAIL" > fails.txt