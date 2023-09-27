#!/usr/bin/env bash

set -e

SECONDS=0
JAVA_BIN="/usr/bin/java" # Java version >= 1.8
JAVAC_BIN="/usr/bin/javac"
KOTLINC_BIN="/usr/bin/kotlinc"

FLOWDROID_ROOT="$(dirname $(realpath "$0"))"
FLOWDROID_BIN="$FLOWDROID_ROOT/soot-infoflow-cmd-jar-with-dependencies.jar"
SOURCES_SINKS="$FLOWDROID_ROOT/SourcesAndSinks.txt"
SOURCES_SINKS_CONTENT="$FLOWDROID_ROOT/SourcesAndSinks_ContentProvider.txt"
ANDROID_JAR="$FLOWDROID_ROOT/android-29.jar"
FLOWDROID_OPT=" -r -mc 99999 -md 99999 -mt 8 -ps"
POMS_DIR="$FLOWDROID_ROOT/../libsec-scraper/poms"
DEPS_ROOT="$FLOWDROID_ROOT/deps"

IVY_BIN="$FLOWDROID_ROOT/ivy-2.5.0.jar"
IVY_SETTINGS="$FLOWDROID_ROOT/ivysettings.xml"
MVN_BIN="/usr/bin/mvn"
MVN_SETTINGS="$FLOWDROID_ROOT/mavensettings.xml"

LIBRARY_ID="$1"  # GROUP_ID+ARTIFACT_ID+VERSION
INPUT_FILE="$2"  # <file>.aar || <file>.jar
OUTPUT_PATH="$3" # <output directory path>
RMODE="$4"       # [deps,flowdroid,normal,content,deps-content] default=normal

RED='\033[0;31m'
NC='\033[0m'

PAC_RESOLVER="ivy" # or mvn

usage() {
    echo "Usage: $0 <GROUPID+ARTIFACTID+VERSION> <jar or aar file> <output directory path> [RMODE]"
    echo "RMODE values:"
    echo "  * normal:       The default value for RMODE. Installs dependencies for the library and runs Flowdroid in leak detection mode."
    echo "    deps:         Installs dependencies for the library and exits."
    echo "    flowdroid:    Runs Flowdroid in leak detection mode without installing dependencies."
    echo "    content:      Runs Flowdroid in content URI detection mode without installing dependencies."
    echo "    deps-content: Installs dependencies for the library and runs Flowdroid in content URI detection mode."
    exit 1
}

error() {
    echo "An error occurred: 
$1"
    exit 1
}

run_flowdroid() {
    # $1 = path to the unzipped jar file
    # $2 = group id
    # $3 = classpath
    # $4 = output file prefix (if any)
    $JAVA_BIN -jar $FLOWDROID_BIN -a $1 -s $SOURCES_SINKS -o $OUTPUT_PATH/${4}flowdroid-results.xml -p $ANDROID_JAR -gi $2 -ac $3 $FLOWDROID_OPT
}

# Check arguments
if [ -z $OUTPUT_PATH ]; then
    # At least one of the arguments is empty
    usage
fi

if [ ! -f $INPUT_FILE ]; then
    error "File $INPUT_FILE does not exist"
fi

mkdir -p $OUTPUT_PATH
OUTPUT_PATH=$(realpath $OUTPUT_PATH)

# Check input file extension
EXT=$(echo ${INPUT_FILE##*.} | tr '[:upper:]' '[:lower:]')
if [[ ! $EXT =~ ^(aar|jar)$ ]]; then
    error "Incorrect file extension: Expected aar or jar but got $EXT"
fi

# Check input file name
BASE_NAME=$(basename $INPUT_FILE)
IFS=+ read -r GROUPID ARTIFACTID VERSION <<<$LIBRARY_ID
if [[ -z $GROUPID || -z $ARTIFACTID || -z $VERSION ]]; then
    error "Incorrect input format: Expected <group id>+<artifact id>+<version> file.<aar|jar> but got $LIBRARY_ID $INPUT_FILE

Example input file name format: com.android.google.material+material+1.6.1 path/to/1.6.1.aar"
fi

DEPS_DIR="$DEPS_ROOT/$GROUPID+$ARTIFACTID/$VERSION"
mkdir -p $DEPS_DIR

# Extract aar/jar file
UNZIPPED=$DEPS_DIR/unzipped
mkdir -p $UNZIPPED
if [ $EXT = "aar" ]; then
    TEMP=$UNZIPPED/temp
    mkdir -p $TEMP
    unzip -o $INPUT_FILE classes.jar -d $TEMP
    unzip -o $TEMP/classes.jar -d $UNZIPPED
    rm -rf $TEMP
else
    unzip -o $INPUT_FILE -d $UNZIPPED
fi

# Dependency resolving
if [[ -z $RMODE || $RMODE == "normal" || $RMODE == "deps" || $RMODE == "deps-content" ]]; then
    pomfile=""
    # Create pom file if PAC_RESOLVER is set to "mvn"
    create_pom() {
        original_pom="$POMS_DIR/$GROUPID/$ARTIFACTID/$VERSION/pom.xml"
        if [[ ! -f $original_pom ]]; then
            return 0
        fi

        mkdir -p $DEPS_DIR/pom
        pomfile=$DEPS_DIR/pom/pom.xml
        cp $original_pom $pomfile
        python3 $FLOWDROID_ROOT/inject_plugin.py "$pomfile"

        echo $(realpath $pomfile)
    }
    [[ $PAC_RESOLVER == "mvn" ]] && pomfile="$(create_pom)"

    # Get all dependencies (except android.jar)
    if [[ $PAC_RESOLVER == "ivy" ]]; then
        get_dependencies() {
            $JAVA_BIN -jar $IVY_BIN -dependency $GROUPID $ARTIFACTID $VERSION -retrieve "$DEPS_DIR/[organization]+[artifact]+[revision](+[classifier]).[ext]" -settings $IVY_SETTINGS -cache cachedir
            rm -f $DEPS_DIR/$BASE_NAME
        }
        get_dependencies 2>&1 | tee $OUTPUT_PATH/ivy-log.txt
    elif [[ $PAC_RESOLVER == "mvn" ]]; then
        get_dependencies() {
            JAVA_HOME="" mvn dependency:copy-dependencies -f $pomfile -DoutputDirectory=$DEPS_DIR -s $MVN_SETTINGS -gs $MVN_SETTINGS -fae
        }
        [ ! -z $pomfile ] && get_dependencies 2>&1 | tee $OUTPUT_PATH/mvn-log.txt || echo "pom.xml was not found"
    fi

    [[ $RMODE == "deps" ]] && exit 0
fi

# Unpack aar dependencies (if there are any)
AAR_DEPS=$(find $DEPS_DIR -name "*.aar")
while IFS= read -r line; do
    [ -z $line ] && break
    tempout=$DEPS_DIR/aar-out
    mkdir -p $tempout
    bname=$(basename $1)
    filename="${bname%.*}"
    unzip -o $line classes.jar -d $tempout
    mv $tempout/classes.jar $DEPS_DIR/$filename.jar
    rm -f $line
    rm -rf tempout
done <<<"$AAR_DEPS"

# Add dependencies to the classpath
CLASSPATH="$ANDROID_JAR:$UNZIPPED"
for lib in $DEPS_DIR/*; do
    [ -f $lib ] && CLASSPATH="$CLASSPATH:$lib"
done

# Run FlowDroid 
if [[ $RMODE == "content" || $RMODE == "deps-content" ]]; then # content URI detection mode
    # Switch the sources-sinks file and use the proper output files
    SOURCES_SINKS=$SOURCES_SINKS_CONTENT
    output_prefix="content-uri-"
    run_flowdroid $UNZIPPED $GROUPID $CLASSPATH $output_prefix 2>&1 | tee $OUTPUT_PATH/${output_prefix}flowdroid-log.txt
    perl -ne 'print "$1\n" if /$Found content URI "(.*)"/' $OUTPUT_PATH/${output_prefix}flowdroid-log.txt | sort -u > $OUTPUT_PATH/content-uris.txt
else # leak detection mode, [-z || flowdroid || normal]
    # Add the one-source-at-a-time option
    FLOWDROID_OPT="$FLOWDROID_OPT -os"
    run_flowdroid $UNZIPPED $GROUPID $CLASSPATH 2>&1 | tee $OUTPUT_PATH/flowdroid-log.txt
fi

# Clean up the temporary directory and exit
echo "Took $SECONDS seconds"
exit 0
