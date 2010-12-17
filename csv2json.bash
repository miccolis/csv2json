#!/bin/bash

# assumptions
# - simple csv, no commas in cells
# - no multi-line rows
# - first line is a header row
# - first item on a row is key of the object.
# - trailing commas are ok

# Hold on to the original IFS value.
_IFS=$IFS;

# The output we're building.
OUTPUT='';

# Return (via `echo`) string name for the attribute
# @param attribute row
# @param index.
function get_attribute {
  INDEX=$2;
  IFS=',';
  for COL in $1; do
    if [ $INDEX == '0' ]; then
      echo "$COL";
      return 0;
    fi
    INDEX=$((INDEX-1));
  done;
  IFS=_IFS;
}

# Transform a comma seperated row into JSON. Places the JSON string in the
# `OUTPUT` variable.
# @param attribute row
# @param input to parse
function parse_row {
  IFS=',';
  INDEX=0;
  for ELEM in $2; do
    if [ $INDEX == '0' ]; then
      OUTPUT="$OUTPUT '$ELEM': {";
    else
      IFS=_IFS;
      COL=$(get_attribute $1 $INDEX);
      OUTPUT="$OUTPUT '$COL': '$ELEM',";
      IFS=',';
    fi
    INDEX=$((INDEX+1));
  done
  OUTPUT="$OUTPUT },";
  IFS=_IFS;
}

# Parse a file, line by line
# @param filename to parse
function parse_file {
  FILE=$1;
  ATTR='';
  for LINE in $(cat $FILE) ; do
    if [ -z $ATTR ]; then
      ATTR=$LINE;
    else
      parse_row $ATTR $LINE;
    fi
  done;
}

if [ ! -f $1 ]; then
  echo "Not a valid file.";
  exit 1;
else
  parse_file $1;
  echo $OUTPUT;
fi

