#!/bin/bash
#
# Assumptions
# - first line is a header row.
# - column names are all simple (no spaces or commas, etc)
# - first item on a row is key of the object, and is simple.
#
# Limitations
# - no multi-line rows
#
#  See also the CSV spec - http://tools.ietf.org/html/rfc4180

# Hold on to the original IFS value.
_IFS=$IFS;

# Validate the header and return (via `echo`) it's length.
# - TODO real validation...
function process_header {
  local COLS=0

  IFS=',';
  for COL in $1; do
    COLS=$(($COLS+1));
  done;
  echo $COLS;
}

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

# Parse a file, line by line
# @param filename to parse
function parse_input {
  local COMMA=0;
  local ELEM='';
  local INDEX=0;
  local PELEM='';
  local PINDEX='';

  # Process header.
  read;
  local COLS=$(process_header $REPLY);
  local ATTR=$REPLY;
  
  # Read and process lines.
  IFS=$'\n';
  while read LINE; do
    if [ $COMMA == 1 ]; then
      echo -n ", ";
    else
      COMMA=1;
    fi

    INDEX=0

    IFS=',';
    # Process elements within lines.
    for ELEM in $LINE; do
      if [ $INDEX == '0' ]; then
        echo -n "\"$ELEM\": {";
      else
        # It's possible that we're:
        # a) at the start of quoted cell.
        # b) in the midst of a quoted cell that contained a comma, or
        # c) in the midst of a quoted cell that contained a `\n`
        IFS=$'\n';
        if [ -n "$PELEM" -o ${ELEM:0:1} == '"' ]; then
          # In case 'a'...
          [ ${ELEM:0:1} == '"' ] && ELEM=${ELEM:1};
          # In case 'b'...
          [ -n "$PELEM" ] && ELEM="$PELEM,$ELEM" && unset PELEM;
          # In case 'c'...

          # Check for, and remove a closing quote here too.
          # TODO we'll have a problem here with '""","'
          if [ ${ELEM:$((${#ELEM}-1))} == '"' ]; then
            ELEM=${ELEM:0:$((${#ELEM}-1))};
          else
            # Don't find the closing double quote? Keep looking.
            PELEM=$ELEM;
            continue;
          fi
        fi;

        ## TODO not sure the best place to do this...
        IFS=$'\n';
        ELEM=$(escape_convert $ELEM)

        IFS=' ';
        echo -n "\"$(get_attribute $ATTR $INDEX)\": \"$ELEM\"";

        # If this isn't the last element add a comma.
        if [ $INDEX -lt $(($COL - 1)) ]; then
          echo -n ',';
        fi;
      fi;
      INDEX=$((INDEX+1));
    done;
    echo -n "}";
  done;
}


if [ -z $1 ]; then
  echo -n '{';
  parse_input;
  echo '}';
elif [ -f $1 ]; then
  cat $1 | $0;
else
  echo "Not a valid file.";
  exit 1;
fi

