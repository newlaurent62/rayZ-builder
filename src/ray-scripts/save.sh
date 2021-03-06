#!/bin/bash

########################################################################
#                                                                      #
#  Here you can edit the script runned each time the session is saved  #
#                                                                      #
#  You have access the following environment variables                 #
#  RAY_SESSION_PATH : Folder of the current session                    #
#  RAY_SCRIPTS_DIR  : Folder containing this script                    #
#     ray-scripts folder can be directly in current session            #
#     or in a parent folder                                            #
#  RAY_PARENT_SCRIPT_DIR : Folder containing the scripts that would    #
#     be runned if RAY_SCRIPTS_DIR would not exists                    #
#                                                                      #
#  To get any other session informations, refers to ray_control help   #
#     typing: ray_control --help                                       #
#                                                                      #
########################################################################


# script here some actions to run before saving the session
USE_JACK_SETTINGS=false
RAY_HOSTNAME_SENSIBLE=false

if [ -f "$RAY_SCRIPTS_DIR/.env" ]; then
  source "$RAY_SCRIPTS_DIR/.env"
fi

export RAY_HOSTNAME_SENSIBLE

if $USE_JACK_SETTINGS; then
  ray-jack_config_script save
fi
ray_control run_step
exit 0

# script here some actions to run after saving the session
