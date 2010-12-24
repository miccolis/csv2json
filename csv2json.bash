#!/bin/bash

# assumptions
# - no multi-line rows
# - support escaped quotes ("") in cells.
# - first line is a header row.
# - column names are all simple (no spaces or commas, etc)
# - first item on a row is key of the object.

# Hold on to the original IFS value.
_IFS=$IFS;

# Return (via `echo`) string name for the attribute
# @param attribute row
# @param index.
function get_attribute {
  local INDEX=$2;

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
  local INDEX=0;
  local ELEM='';

  IFS=',';
  for ELEM in $3; do
    if [ $INDEX == '0' ]; then
      echo -n "\"$ELEM\": {";
    else
      # It's possible that we're:
      # a) in the midst of a cell that contained a comma, or
      # b) at the start of cell that begins with a comma.
      if [ -n "$PREVE" -o ${ELEM:0:1} == '"' ]; then
        # In case 'a'...
        [ -n "$PREVE" ] && ELEM="$PREVE,$ELEM" && unset PREVE;
        # In case 'b'...
        [ ${ELEM:0:1} == '"' ] && ELEM=${ELEM:1};

        # Check for, and remove a closing quote here too.
        if [ ${ELEM:$((${#ELEM}-1))} == '"' ]; then
          ELEM=${ELEM:0:$((${#ELEM}-1))};
        else
          # Don't find the closing double quote? Keep looking.
          PREVE=$ELEM;
          continue;
        fi
      fi

      IFS=_IFS;
      echo -n "\"$(get_attribute $1 $INDEX)\": \"$ELEM\"";
      IFS=',';

      # If this isn't the last element add a comma.
      if [ $INDEX -lt $(($2 - 1)) ]; then
        echo -n ',';
      fi;
    fi
    INDEX=$((INDEX+1));
  done
  echo -n "}";
  IFS=_IFS;
}

# Validate the header and return (via `echo`) it's length.
# - TODO real validation...
function process_header {
  local COLS=0

  IFS=',';
  for COL in $1; do
    COLS=$(($COLS+1));
  done;
  IFS=_IFS;
  echo $COLS;
}

# Parse a file, line by line
# @param filename to parse
function parse_input {
  local ATTR='';
  local COMMA=0;

  echo -n '{';
  IFS=$'\n';
  while read LINE; do
    if [ -z $ATTR ]; then
      COLS=$(process_header $LINE);
      ATTR=$LINE;
    else
      if [ $COMMA == 1 ]; then
        echo -n ", ";
      else
        COMMA=1;
      fi
      echo -n $(parse_row $ATTR $COLS $LINE);
    fi
  done;
  IFS=_IFS;
  echo '}';
}

if [ -z $1 ]; then
  parse_input;
elif [ -f $1 ]; then
  cat $1 | $0;
else
  echo "Not a valid file.";
  exit 1;
fi

