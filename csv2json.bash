#!/bin/bash

# assumptions
# - simple csv, no commas in cells
# - no multi-line rows
# - first line is a header row.
# - column names are all simple (no spaces or commas, etc)
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
# @param number of attributes
# @param input to parse
function parse_row {
  IFS=',';
  INDEX=0;
  for ELEM in $3; do
    if [ $INDEX == '0' ]; then
      echo "'$ELEM': {";
    else
      IFS=_IFS;
      echo "'$(get_attribute $1 $INDEX)': '$ELEM'";
      IFS=',';

      # If this isn't the last element add a comma.
      if [ $INDEX -lt $(($2 - 1)) ]; then
        echo ',';
      fi;
    fi
    INDEX=$((INDEX+1));
  done
  echo "}";
  IFS=_IFS;
}

#Validate the header
function process_header {
  IFS=',';
  COLS=0
  for COL in $1; do
    COLS=$(($COLS+1));
  done;
  echo $COLS;
}

# Parse a file, line by line
# @param filename to parse
function parse_file {
  OUTPUT='';
  ATTR='';
  COMMA=0;

  # TODO probably need to set the IFS to \n
  for LINE in $(cat $1) ; do
    if [ -z $ATTR ]; then
      COLS=$(process_header $LINE);
      ATTR=$LINE;
    else
      if [ $COMMA -gt 0 ]; then
        OUTPUT="$OUTPUT,";
      else
        COMMA=1;
      fi
      OUTPUT="$OUTPUT $(parse_row $ATTR $COLS $LINE)";
    fi
  done;
  echo $OUTPUT;
}

if [ ! -f $1 ]; then
  echo "Not a valid file.";
  exit 1;
else
  echo $(parse_file $1);
fi

