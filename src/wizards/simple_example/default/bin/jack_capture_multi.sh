#!/bin/bash
function sigterm() {
  trap '' TERM
  if [ "$PID" != "" ]; then
    echo "Propagate TERM to $PID ..."
    kill -TERM "$PID"
    wait $PID
  fi
  
}

# function sigint() {
#   
#   if [ "$PID" != "" ]; then
#     echo "Propagate INT to $PID ..."
#     kill -INT "$PID"
#   fi
#   
# }

function sigusr1() {
  
  if [ "$PID" != "" ]; then
    echo "Propagate USR1 to $PID ..."
    kill -USR1 "$PID"
  fi
  
}

function sigusr2() {
  
  if [ "$PID" != "" ]; then
    echo "Propagate USR2 to $PID ..."
    kill -USR2 "$PID"
  fi
  
}


function sighup() {
  
  if [ "$PID" != "" ]; then
    echo "Propagate HUP to $PID ..."
    kill -HUP "$PID"
  fi
  
}

trap sigterm TERM

trap sigterm INT

trap sigusr1 USR1

trap sigusr2 USR2

trap sighup HUP


COMMAND="jack_capture --jack-transport $@" 
echo "executing $COMMAND"
while true ; 
do 
  $COMMAND || exit 1
done
