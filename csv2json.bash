#!/bin/bash
#
# Assumptions
# - first line is a header row.
# - first item on a row is key of the object, and is simple.
# - Unescaped quotes within cells are tolerated, and escaped.
#
# Limitations
# - Does not support semicolon as seperator.
# - "Simple" fields cannot contain  linebreaks.
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
# @param index.
# @param attribute row
function get_attribute {
  local INDEX=$1;

  IFS=',';
  for COL in $2; do
    if [ $INDEX == '0' ]; then
      if [ ${COL:0:1} == '"' -a ${COL:$((${#FOO}-1)):1} == '"' ]; then
        echo "$COL";
      else
        echo "\"$COL\"";
      fi
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
  local COLS=$(process_header "$REPLY");
  local ATTR=$REPLY;
  
  # Read and process lines.
  read && LINE=$REPLY;
  while [ -n "$LINE" ]; do
    [ $COUNT -gt 0 ] && echo -n ',';
    while [ $INDEX -lt $COLS ]; do
      SIMPLE=1 && POS=0;
      # If this is a complex cell, unset the simple flag and strip the leading
      # double quote.
      [ "${LINE:0:1}" == '"' ] && SIMPLE=0 && LINE=${LINE:1};

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
          # Two double quotes are an `escaped` quote, switch to JSON escapes.
          if [ $((POS+1)) -lt ${#LINE} -a "${LINE:$POS:2}" == '""' ]; then
            ESCAPED='\"';
            LINE="${LINE:0:$POS}$ESCAPED${LINE:$((POS+2))}"
            POS=$((POS+1));
          elif [ "${LINE:$POS:1}" == '"' ]; then
            # Sometimes there will be an unescaped quote in the middle of a
            # cell. This isn't allowed, but we're going to tolerate it for now.
            # TODO Remove this.
            if [ "${LINE:$POS:2}" != '",' -a $((POS+1)) != ${#LINE} ]; then
              ESCAPED='\"';
              LINE="${LINE:0:$POS}$ESCAPED${LINE:$((POS+2))}";
              POS=$((POS+2)) && continue;
            fi
            OUT=${LINE:0:$POS} && LINE=${LINE:$((POS+2))} && break;
          fi
          # If we don't have output and we're at the end of the line we've got
          # a line break in the cell, so pull the next line in.
          if [ -z "$OUT" -a $((POS+1)) == ${#LINE} ]; then
            read && LINE="$LINE\n$REPLY";
          fi
        fi
        POS=$((POS+1));
      done;

      [ $INDEX == 0 ] && printf '%s' "{";
      [ $INDEX -gt 0 ] && printf '%s' ',';

      IFS=' ';
      printf '%s' "$(get_attribute $INDEX "$ATTR"): \"$OUT\"";

      unset OUT;
      INDEX=$((INDEX+1));
    done;
    echo -n "}" && COUNT=$((COUNT+1));
    unset LINE && read && LINE=$REPLY && INDEX=0;
    #echo "Count $COUNT :: Next -> ${LINE:0:34}" 1>&2;
  done;
}


if [ -z $1 ]; then
  echo -n '[';
  convert_file
  echo ']';
elif [ -f $1 ]; then
  cat $1 | $0;
else
  echo "Not a valid file.";
  exit 1;
fi

