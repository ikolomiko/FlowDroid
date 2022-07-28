#!/usr/bin/env bash

SECONDS=0
JAVA_BIN="/usr/bin/java"
FLOWDROID="$HOME/git-repos/FlowDroid/soot-infoflow-cmd/target/soot-infoflow-cmd-jar-with-dependencies.jar"
INPUT_FILE="$1"
OUTPUT_XML="$2"
ANDROID_PLATFORMS="$HOME/Android/platforms"
SOURCES_SINKS="$HOME/libsec/flowdroid/SourcesAndSinks.txt"
FLOWDROID_OPT=" -ls -r -os -mc 99999 -md 99999 -mt 8 -ps"

usage() {
  echo "Usage: ./analyze.sh <jar or aar file> <output xml file>"
  exit 1
}

error() {
  echo "An error occurred: $1"
  exit 1
}

run_flowdroid() { # $1 = path to the unzipped jar file
  $JAVA_BIN -jar $FLOWDROID -a $1 -s $SOURCES_SINKS -o $OUTPUT_XML -p $ANDROID_PLATFORMS $FLOWDROID_OPT
}

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


EXT=`echo ${INPUT_FILE##*.} | tr '[:upper:]' '[:lower:]'`
if [[ ! $EXT =~ ^(aar|jar)$ ]]; then
  error "Incorrect file extension: Expected aar or jar but got $EXT"
fi

TEMP=`mktemp -d`
if [ $EXT = "aar" ]; then
  unzip $INPUT_FILE classes.jar -d /tmp
  unzip /tmp/classes.jar -d $TEMP
  rm /tmp/classes.jar
else
  unzip $INPUT_FILE -d $TEMP
fi

run_flowdroid $TEMP

rm -r $TEMP
echo "Took $SECONDS seconds"
exit 0
