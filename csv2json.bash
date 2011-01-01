#!/bin/bash
#
# Assumptions
# - first line is a header row.
# - column names are all simple (no spaces or commas, etc)
# - first item on a row is key of the object, and is simple.
#
#  See also:
#   CSV RFC - http://tools.ietf.org/html/rfc4180
#   JSON - http://www.json.org/

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
      SIMPLE=1 && POS=0;

      # After the first element we'll need a comma.
      [ $INDEX -gt 1 ] && echo -n ',';

      # If this is a complex cell, unset the simple flag and strip the leading
      # double quote.
      [ ${LINE:0:1} == '"' ] && SIMPLE=0 && LINE=${LINE:1};

      # Walk the line, striping off completed cells.
      while [ $POS -lt ${#LINE} ]; do
        if [ $SIMPLE == 1 ]; then
          if [ "${LINE:$POS:1}" == ',' ]; then
            OUT=${LINE:0:$POS} && LINE=${LINE:$((POS+1))} && break;
          elif [ $((POS+1)) == ${#LINE} -a $((INDEX+1)) == $COLS ]; then
            # TODO error handling if a line is missing cells.
            OUT=${LINE:0:$((POS+1))} && LINE=${LINE:$POS} && break;
          fi
        else
          ## Two double quotes are an `escaped` quote, switch to JSON escapes.
          if [ $((POS+1)) -lt ${#LINE} -a ${LINE:$POS:2} == '""' ]; then
            ESCAPED='\"';
            LINE="${LINE:0:$POS}$ESCAPED${LINE:$((POS+2))}"
            POS=$((POS+1));
          elif [ "${LINE:$POS:1}" == '"' ];then
            # TODO error handling if a cell is prematurely closed.
            OUT=${LINE:0:$POS} && LINE=${LINE:$((POS+2))} && break;
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

