#!/bin/bash

# assumptions
# - no multi-line rows
# - support for escaped quotes ("") in cells.
# - first line is a header row.
# - column names are all simple (no spaces or commas, etc)
# - first item on a row is key of the object.

# http://tools.ietf.org/html/rfc4180

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

# We need to `unescape` the quotes, this means de-duping quotes and
# removing trailing quotes, and JSON escape them. ...converted to single quotes for now...
# @param string to unescape.
function escape_convert {
  local ELEM=$1;
  local FOUND;
  local POS=0;
  local LEN=${#ELEM};

  while [ "$POS" -lt "$LEN" ]; do
    if [ "${ELEM:$POS:1}" == '"' ]; then
      if [ -z "$FOUND" ]; then
        FOUND=$POS;
      elif [ "$FOUND" == "$((POS-1))" ]; then
        ELEM="${ELEM:0:$((POS-1))}'${ELEM:$((POS+1))}"
        unset FOUND;
        POS=$((POS-1));
      else
        # TODO proper error handling, we've ended the cell prematurely because it
        # was badly formatted. (it had an unescaped quote in the  middle of the
        # cell.
        echo ${ELEM:0:$FOUND};
        return 1;
      fi
    fi
    POS=$((POS+1));
  done;

  echo $ELEM;
  return 0;
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
      # a) in the midst of a quoted cell that contained a comma, or
      # b) at the start of quoted cell.
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

      IFS=$'\n';
      ELEM=$(escape_convert $ELEM)

      IFS=' ';
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
  COMMA=0;

  # Process header.
  read;
  COLS=$(process_header $REPLY);
  ATTR=$REPLY;

  echo -n '{';
  IFS=$'\n';
  while read LINE; do
    if [ $COMMA == 1 ]; then
      echo -n ", ";
    else
      COMMA=1;
    fi
    echo -n $(parse_row $ATTR $COLS $LINE);
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

