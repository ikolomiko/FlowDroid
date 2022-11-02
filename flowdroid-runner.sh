#!/usr/bin/env bash
LIBS_ROOT="../libsec-scraper/updated-libs"

SECONDS=0
GREEN='\033[0;32m'
NC='\033[0m'
OUTPUT_ROOT="$1"
if [ -z $1 ]; then
    echo "usage: bash flowdroid-runner.sh <output dir>"
    exit 1
fi

mkdir -p $OUTPUT_ROOT
OUTPUT_ROOT=$(realpath $OUTPUT_ROOT)

start_analysis() {
#LIBRARY_ID="$1" # GROUP_ID+ARTIFACT_ID+VERSION
#INPUT_FILE="$2" # <file>.aar || <file>.jar
#OUTPUT_PATH="$3" # <output directory path>

 ./flowdroid-libsec-wrapper.sh $1 $2 $3
}

ITER=0
folders="$(find $LIBS_ROOT -mindepth 1 -maxdepth 1 -type d)"
TOTAL=$(wc -l <<< "$folders")
for subfolder in $folders; do
    ((++ITER))
    echo -e "${GREEN}Folder $ITER/$TOTAL ${NC}"
    base_id=$(basename $subfolder)
    for file in $(find $subfolder -mindepth 1 -maxdepth 1 -type f -name "*.aar" -or -name "*.jar"); do
        filename=$(basename $file)
        version="${filename%.*}"
        library_id="$base_id+$version"
        input_file=$(realpath $file)
        mkdir -p $OUTPUT_ROOT/$base_id/$version

        start_analysis $library_id $input_file $(realpath $OUTPUT_ROOT/$base_id/$version)
    done
done

echo -e "${GREEN}Took $SECONDS seconds to finish them all${NC}"
