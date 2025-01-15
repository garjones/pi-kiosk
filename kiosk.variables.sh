#!/bin/bash

# debug flag
DEBUG=TRUE
SCREEN_WIDTH=1024
SCREEN_HEIGHT=968

# check for debug mode
is_debug () {
  if [ "$DEBUG" = TRUE ]; then
    return 0
  else
    return 1
  fi
}
