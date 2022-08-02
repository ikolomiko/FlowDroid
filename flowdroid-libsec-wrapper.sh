#!/usr/bin/env bash

SECONDS=0
JAVA_BIN="/usr/bin/java"
JAVAC_BIN="/usr/bin/javac"
KOTLINC_BIN="/usr/bin/kotlinc"
ANDROID_JAR="$HOME/Android/platforms/android-29/android.jar"

FLOWDROID_ROOT="$(dirname $(realpath "$0"))"
FLOWDROID_BIN="$FLOWDROID_ROOT/soot-infoflow-cmd/target/soot-infoflow-cmd-jar-with-dependencies.jar"
CLASSPATH_DEPS="$FLOWDROID_ROOT/classpath-deps/"
SOURCES_SINKS="$FLOWDROID_ROOT/SourcesAndSinks.txt"
FLOWDROID_OPT=" -ls -r -os -mc 99999 -md 99999 -mt 8 -ps"

INPUT_FILE="$1"
OUTPUT_XML="$2"

usage() {
  echo "Usage: ./analyze.sh <jar or aar file> <output xml file>"
  exit 1
}

error() {
  echo "An error occurred: $1"
  exit 1
}

run_flowdroid() { # $1 = path to the unzipped jar file
  $JAVA_BIN -jar $FLOWDROID_BIN -a $1 -s $SOURCES_SINKS -o $OUTPUT_XML -p $ANDROID_JAR $FLOWDROID_OPT
}


# Check arguments
if [ -z $OUTPUT_XML ]; then
  # Either the second or both arguments are empty
  usage
fi

if [ ! -f $INPUT_FILE ]; then
  error "File $INPUT_FILE does not exist"
fi

if [ -f $OUTPUT_XML ]; then
  rm $OUTPUT_XML
fi


# Check input file extension
EXT=`echo ${INPUT_FILE##*.} | tr '[:upper:]' '[:lower:]'`
if [[ ! $EXT =~ ^(aar|jar)$ ]]; then
  error "Incorrect file extension: Expected aar or jar but got $EXT"
fi


# Extract aar/jar file
TEMP=`mktemp -d`
if [ $EXT = "aar" ]; then
  unzip $INPUT_FILE classes.jar -d /tmp
  unzip /tmp/classes.jar -d $TEMP
  rm /tmp/classes.jar
else
  unzip $INPUT_FILE -d $TEMP
fi


# Add some 1st party dependencies (androidx, android.support, kotlin stdlib...)
#to the classpath
DEPENDENCIES=`ls $CLASSPATH_DEPS`
CLASSPATH="$ANDROID_JAR:$TEMP"
for lib in $DEPENDENCIES
do
  CLASSPATH="$CLASSPATH:$CLASSPATH_DEPS$lib"
done


# Find java and kotlin source files
JAVA_FILES=$(find $TEMP -name '*.java')
KOTLIN_FILES=$(find $TEMP -name '*.kt')


# Compile source files to bytecode
cd $TEMP
[[ ! -z $JAVA_FILES ]] && javac -cp $CLASSPATH $JAVA_FILES
[[ ! -z $KOTLIN_FILES ]] && kotlinc -classpath $CLASSPATH $KOTLIN_FILES


# Run FlowDroid (what a useful comment)
run_flowdroid $TEMP 


# Clean up the temporary directory and exit
rm -r $TEMP
echo "Took $SECONDS seconds"
exit 0
