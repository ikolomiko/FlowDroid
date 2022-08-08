#!/usr/bin/env bash
set -e

SECONDS=0
JAVA_BIN="/usr/bin/java" # Java version >= 1.8
JAVAC_BIN="/usr/bin/javac"
KOTLINC_BIN="/usr/bin/kotlinc"
ANDROID_JAR="$HOME/Android/platforms/android-29/android.jar"

FLOWDROID_ROOT="$(dirname $(realpath "$0"))"
FLOWDROID_BIN="$FLOWDROID_ROOT/soot-infoflow-cmd/target/soot-infoflow-cmd-jar-with-dependencies.jar"
SOURCES_SINKS="$FLOWDROID_ROOT/SourcesAndSinks.txt"
FLOWDROID_OPT=" -ls -r -os -mc 99999 -md 99999 -mt 8 -ps"

IVY_BIN="$FLOWDROID_ROOT/ivy-2.5.0.jar"
IVY_SETTINGS="$FLOWDROID_ROOT/ivysettings.xml"

INPUT_FILE="$1" # GROUPID+ARTIFACTID+VERSION.aar || GROUPID+ARTIFACTID+VERSION.jar
OUTPUT_XML="$2"

usage() {
  echo "Usage: ./analyze.sh <jar or aar file> <output xml file>"
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
  $JAVA_BIN -jar $FLOWDROID_BIN -a $1 -s $SOURCES_SINKS -o $OUTPUT_XML -p $ANDROID_JAR -gi $2 -ac $3 $FLOWDROID_OPT
}


# Check arguments
if [ -z $OUTPUT_XML ]; then
  # Either the second or both arguments are empty
  usage
fi

if [ ! -f $INPUT_FILE ]; then
  error "File $INPUT_FILE does not exist"
fi

OUTPUT_XML=$(realpath $OUTPUT_XML)

if [ -f $OUTPUT_XML ]; then
  rm $OUTPUT_XML
fi


# Check input file extension
EXT=$(echo ${INPUT_FILE##*.} | tr '[:upper:]' '[:lower:]')
if [[ ! $EXT =~ ^(aar|jar)$ ]]; then
  error "Incorrect file extension: Expected aar or jar but got $EXT"
fi


# Check input file name
BASE_NAME=$(basename $INPUT_FILE)
IFS=+ read -r GROUPID ARTIFACTID VERSION <<< $BASE_NAME
VERSION=${VERSION%.*}
if [[ -z $GROUPID || -z $ARTIFACTID || -z $VERSION ]]; then
  error "Incorrect file name format: Expected <group id>+<artifact id>+<version>.<aar|jar> but got $BASE_NAME

Example input file name format: com.android.google.material+material+1.6.1.aar"
fi

# Extract aar/jar file
TEMP=$(mktemp -d)
mkdir /tmp/libsec -p
if [ $EXT = "aar" ]; then
  rm -f /tmp/classes.jar
  unzip $INPUT_FILE classes.jar -d /tmp
  unzip /tmp/classes.jar -d $TEMP
  mv /tmp/classes.jar "/tmp/libsec/$GROUPID+$ARTIFACTID+$VERSION.jar"
else
  unzip $INPUT_FILE -d $TEMP
  cp $INPUT_FILE /tmp/libsec/
fi


# Get all dependencies (except android.jar)
DEPS_DIR=$(mktemp -d)
$JAVA_BIN -jar $IVY_BIN -dependency $GROUPID $ARTIFACTID $VERSION -retrieve "$DEPS_DIR/[organization]+[artifact]+[revision](+[classifier]).[ext]" -settings $IVY_SETTINGS
rm -f $DEPS_DIR/$BASE_NAME


# Unpack aar dependencies (if there are any)
AAR_DEPS=$(find $DEPS_DIR -name "*.aar")
while IFS= read -r line; do
  [ -z $line ] && break
  unzip $line classes.jar -d "$DEPS_DIR/$(uuidgen).jar"
  rm -f $line
done <<< "$AAR_DEPS"


# Add dependencies to the classpath
CLASSPATH="$ANDROID_JAR:$TEMP"
for lib in $DEPS_DIR/*
do
  [ -f $lib ] && CLASSPATH="$CLASSPATH:$lib"
done


# Find java and kotlin source files
JAVA_FILES=$(find $TEMP -name '*.java')
KOTLIN_FILES=$(find $TEMP -name '*.kt')


# Compile source files to bytecode
cd $TEMP
[[ ! -z $JAVA_FILES ]] && javac -proc:none -cp $CLASSPATH $JAVA_FILES
[[ ! -z $KOTLIN_FILES ]] && kotlinc -classpath $CLASSPATH $KOTLIN_FILES


# Run FlowDroid (what a useful comment)
run_flowdroid $TEMP $GROUPID $CLASSPATH


# Clean up the temporary directory and exit
rm -r $TEMP
rm -r $DEPS_DIR
echo "Took $SECONDS seconds"
exit 0
