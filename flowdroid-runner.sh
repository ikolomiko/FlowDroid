#!/usr/bin/env bash
LIBS_ROOT="../libsec-scraper/updated-libs"

SECONDS=0
GREEN='\033[0;32m'
NC='\033[0m'
OUTPUT_ROOT="$1"
RMODE="$2"
if [ -z $1 ]; then
    echo "usage: $0 <output dir> [RMODE]"
    echo "RMODE values:"
    echo "  * normal:       The default value for RMODE. Installs dependencies for the libraries and runs Flowdroid in leak detection mode."
    echo "    deps:         Installs dependencies for the libraries and exits."
    echo "    flowdroid:    Runs Flowdroid in leak detection mode without installing dependencies."
    echo "    content:      Runs Flowdroid in content URI detection mode without installing dependencies."
    echo "    deps-content: Installs dependencies for the libraries and runs Flowdroid in content URI detection mode."
    exit 1
fi

mkdir -p $OUTPUT_ROOT
OUTPUT_ROOT=$(realpath $OUTPUT_ROOT)

start_analysis() {
    #LIBRARY_ID="$1" # GROUP_ID+ARTIFACT_ID+VERSION
    #INPUT_FILE="$2" # <file>.aar || <file>.jar
    #OUTPUT_PATH="$3" # <output directory path>
    #RMODE="$4" # [normal,deps,flowdroid,content,deps-content], default=normal

    ./flowdroid-libsec-wrapper.sh $1 $2 $3 $4
}

inner_for_loop() {
    #$1=subfolder
    #$2=output root
    #$3=RMODE
    subfolder=$1
    OUTPUT_ROOT=$2
    RMODE=$3

    base_id=$(basename $subfolder)
    for file in $(find $subfolder -mindepth 1 -maxdepth 1 -type f -name "*.aar" -or -name "*.jar"); do
        filename=$(basename $file)
        version="${filename%.*}"
        library_id="$base_id+$version"
        input_file=$(realpath $file)
        mkdir -p $OUTPUT_ROOT/$base_id/$version
        [ -f $OUTPUT_ROOT/$base_id/$version/flowdroid-results.xml ] && continue

        start_analysis $library_id $input_file $(realpath $OUTPUT_ROOT/$base_id/$version) $RMODE
    done
}
export -f inner_for_loop start_analysis

# ITER=0
folders="$(find $LIBS_ROOT -mindepth 1 -maxdepth 1 -type d)"
TOTAL=$(wc -l <<<"$folders")

echo "Getting dependencies" >> status.txt

# Get dependencies in non-parallelized fashion
if [[ $2 != "flowdroid" ]]; then
    for subfolder in $folders; do
        ((++ITER))
        echo -e "${GREEN}Folder $ITER/$TOTAL ${NC}"
        inner_for_loop $subfolder $OUTPUT_ROOT "deps"
    done
fi

echo "Running flowdroid" >> status.txt

# Run flowdroid in parallel
if [[ $2 != "deps" ]]; then
    parallel -j 50 --bar inner_for_loop ::: $folders ::: $OUTPUT_ROOT ::: "flowdroid"
fi

echo -e "${GREEN}Took $SECONDS seconds to finish them all${NC}"
