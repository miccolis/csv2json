#!/bin/bash

# assumptions
# - simple csv, no commas in cells
# - no multi-line rows
# - first line is a header row
# - first item on a row is key of the object.
# - trailing commas are ok

# Hold on to the original IFS value.
_IFS=$IFS;

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

# Transform a comma seperated row into JSON. `echo`s the JSON string as it is
# built.
# @param attribute row
# @param input to parse
function parse_row {
  IFS=',';
  INDEX=0;
  for ELEM in $2; do
    if [ $INDEX == '0' ]; then
      echo "'$ELEM': {";
    else
      IFS=_IFS;
      echo "'$(get_attribute $1 $INDEX)': '$ELEM',";
      IFS=',';
    fi
    INDEX=$((INDEX+1));
  done
  echo "},";
  IFS=_IFS;
}

# Parse a file, line by line
# @param filename to parse
function parse_file {
  OUTPUT='';
  ATTR='';

  for LINE in $(cat $1) ; do
    if [ -z $ATTR ]; then
      ATTR=$LINE;
    else
      echo "$OUTPUT $(parse_row $ATTR $LINE)";
    fi
  done;
}

if [ ! -f $1 ]; then
  echo "Not a valid file.";
  exit 1;
else
  echo $(parse_file $1);
fi

