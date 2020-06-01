#!/bin/bash

########################################################################
#                                                                      #
#  Here you can edit the script runned                                 #
#  each time daemon order this session to be closed                    #
#  WARNING: You can be here in a switch situation,                     #
#           a session can be opened just after.                        #
#                                                                      #
#  You have access the following environment variables                 #
#  RAY_SESSION_PATH : Folder of the current session                    #
#  RAY_FUTURE_SESSION_PATH: Folder of the session that will be opened  #
#     just after current session close.                                #
#  RAY_SCRIPTS_DIR  : Folder containing this script                    #
#     ray-scripts folder can be directly in current session            #
#     or in a parent folder.                                           #
#  RAY_PARENT_SCRIPT_DIR : Folder containing the scripts that would    #
#     be runned if RAY_SCRIPTS_DIR would not exists                    #
#  RAY_SWITCHING_SESSION: 'true' or 'false'                            #
#     'true' if session is switching from another session              #
#     and probably some clients are still alive.                       #
#                                                                      #
#  To get any other session informations, refers to ray_control help   #
#     typing: ray_control --help                                       #
#                                                                      #
########################################################################


# script here some actions to run before closing the session.


# some clients may keep alive because
# they are needed by the session to open just after.
# if for some reasons you want all clients to stop
# set this variable true !
close_all_clients=false
USE_CATIA=1

if [ -f "$RAY_SCRIPTS_DIR/.env" ]; then
  source "$RAY_SCRIPTS_DIR/.env"
fi


if [ $USE_CATIA -eq 1 ]
then
  RAY_SESSION_NAME="$(basename "$RAY_SESSION_PATH")"
  echo "RAY_SESSION_PATH: $RAY_SESSION_PATH"
  echo "RAY_SESSION_NAME: $RAY_SESSION_NAME"  
  if [ -d "/tmp/catia" ]
  then
    mv "/tmp/catia/${RAY_SESSION_NAME}.yml" "/tmp/catia/${RAY_SESSION_NAME}.yml.session_closed" || exit 1
    touch "/tmp/catia/${RAY_SESSION_NAME}.yml.session_closed" || exit 1
  fi
fi

close_all_if_needed=''

if [[ "$RAY_FUTURE_SCRIPTS_DIR" != "$RAY_SCRIPTS_DIR" ]] &&\
        ! [ -f "$RAY_FUTURE_SCRIPTS_DIR/.jack_config_script" ];then
    close_all_if_needed=close_all
fi

ray_control run_step $close_all_if_needed

if [ -n "$close_all_if_needed" ];then
    ray-jack_config_script putback && ray_control hide_script_info
fi




# script here some actions to run once the session is closed


