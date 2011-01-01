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

function convert_file {
  local COUNT=0; # row counter
  local INDEX=0; # current index.
  local POS=0; # char index.
  local SIMPLE=1; # `0` if current cell is quoted, `1` if it's simple.
  local LINE; # Current line being processed.
  local OUT; # Value of a cell.

  # Process header.
  read;
  local COLS=$(process_header $REPLY);
  local ATTR=$REPLY;
  
  # Read and process lines.
  read && LINE=$REPLY;
  while [ -n "$LINE" ]; do
    [ $COUNT -gt 0 ] && echo -n ',';
    while [ $INDEX -lt $COLS ]; do
      [ $INDEX -gt 1 ] && echo -n ',';
      # If this is a complex cell, unset the simple flag and strip the leading
      # double quote.
      if [ ${LINE:0:1} == '"' ]; then
        SIMPLE=0;
        LINE=${LINE:1};
      fi
      # Walk the line, striping off completed cells.
      while [ $POS -lt ${#LINE} ]; do
        if [ $SIMPLE == 1 ]; then
          if [ "${LINE:$POS:1}" == ',' ]; then
            OUT=${LINE:0:$POS} && LINE=${LINE:$((POS+1))} && POS=0 && break;
          elif [ $((POS+1)) == ${#LINE} -a $((INDEX+1)) == $COLS ]; then
            # TODO error handling if a line is missing cells.
            OUT=${LINE:0:$((POS+1))} && LINE=${LINE:$POS} && break;
          fi
        else
          ## Two double quotes are an `escaped` quote, ignore them.
          if [ $((POS+1)) -lt ${#LINE} -a ${LINE:$POS:2} == '""' ]; then
            POS=$((POS+1));
          elif [ "${LINE:$POS:1}" == '"' ];then
            # TODO error handling if a cell is prematurely closed.
            SIMPLE=1 && POS=0;
            OUT=${LINE:0:$POS} && LINE=${LINE:$POS} && break;
          fi
          # If we don't have output and we're at the end of the line we've got
          # a line break in the cell, so pull the next line in.
          if [ -z "$OUT" -a $((POS+1)) == ${#LINE} ]; then
            # TODO this newline creation is broken.
            read && LINE="$LINE\n$REPLY";
          fi
        fi
        POS=$((POS+1));
      done;

      IFS=$'\a'; # Split on the `bell`, they'll never use that!
      OUT=$(escape_convert $OUT)

      if [ $INDEX == 0 ]; then
        echo -n "\"$OUT\": {";
      else
        IFS=' ';
        echo -n "\"$(get_attribute $ATTR $INDEX)\": \"$OUT\"";
      fi

      unset OUT;
      INDEX=$((INDEX+1));
    done;
    echo -n "}" && COUNT=$((COUNT+1));
    unset LINE && read && LINE=$REPLY && POS=0 && INDEX=0 && SIMPLE=1;
  done;
}


if [ -z $1 ]; then
  echo -n '{';
  convert_file
  echo '}';
elif [ -f $1 ]; then
  cat $1 | $0;
else
  echo "Not a valid file.";
  exit 1;
fi

