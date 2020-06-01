<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">#!/bin/bash

#=======================================================================
#                                                                      =
#  Here you can edit the script runned                                 =
#  each time daemon order this session to be loaded                    =
#  WARNING: You can be here in a switch situation,                     =
#           some clients may be still alive                            =
#           if they are NSM compatible and capable of switch           =
#           or if they are not NSM compatible at all                   =
#                 and launched directly (not via proxy)                =
#                                                                      =
#  You have access the following environment variables                 =
#  RAY_SESSION_PATH : Folder of the current session                    =
#  RAY_SCRIPTS_DIR  : Folder containing this script                    =
#     ray-scripts folder can be directly in current session            =
#     or in a parent folder.                                           =
#  RAY_PARENT_SCRIPT_DIR : Folder containing the scripts that would    =
#     be runned if RAY_SCRIPTS_DIR would not exists                    =
#  RAY_SWITCHING_SESSION: 'true' or 'false'                            =
#     'true' if session is switching from another session              =
#     and probably some clients are still alive.                       =
#                                                                      =
#  To get any other session informations, refers to ray_control help   =
#     typing: ray_control --help                                       =
#                                                                      =
#=======================================================================



# script here some actions to run before loading the session.

# [VARIABLES]
CHECK_SERVER=1
USE_JACK=1
USE_JACK_SETTINGS=0
CHECK_ADDITIONNAL_AUDIO_DEVICES=1
CHECK_PROGRAMS=1
USE_CATIA=1

if [ -f "\$RAY_SCRIPTS_DIR/.env" ]; then
  source "\$RAY_SCRIPTS_DIR/.env"
fi

# [/VARIABLES]

function check_server_running() {
  if [ "\$(which systemctl)" != "" ]
  then
    SERVICE="\$(systemctl --all --type service | grep "\$1" | awk '{print \$1}')"
    if [ "\$SERVICE" != "" ];then
        echo "\$1 has been found in systemd."
        if [ "\$(systemctl status \$SERVICE | grep "active (running)")" == "" ]
        then
          
          if ray_control script_user_action "It seems that \$1 is not running in systemd. This RaySession use it. Please start it using 'sudo systemctl start \$SERVICE'. Do you want to stop loading the session ?"; then
            echo "The session load has been aborted by user."
            ray_control script_info "The session load has been aborted by user."
            exit 0
          fi
        fi
    else
        echo "\$1 does not exist in systemd."
        if ray_control script_user_action "It seems that \$1 is not installed in systemd. This RaySession use it. Please install it. Do you want to stop loading the session ?"; then
          echo "The session load has been aborted by user."
          ray_control script_info "The session load has been aborted by user."
          exit 0
        fi
    fi
  fi
}

function restart_server_with_session_settings() {  
  if jack_control status; then
    jack_control stop
  fi
  jack_control  eps name default
  jack_control  ds alsa 
  jack_control  eps realtime true
  jack_control  dps rate \$JACK_SAMPLERATE
  jack_control  dps period \$JACK_PERIOD  
  jack_control  dps device hw:\$JACK_INTERFACE
  jack_control  dps playback hw:\$JACK_INTERFACE
  jack_control  dps capture hw:\$JACK_INTERFACE

  jack_control start
}

if [ \$USE_JACK -eq 1 ]
then
  ray-jack_config_script load || exit 0
  ray_control hide_script_info

<!--  if [ \$USE_JACK_SETTINGS -eq 1 -a -f "\$RAY_SESSION_PATH/default/jack_settings.env" ]; then
    source "\$RAY_SESSION_PATH/default/jack_settings.env"
    
    if [ "\$JACK_INTERFACE" != "" -a "\$JACK_PERIOD" != "" -a "\$JACK_SAMPLERATE" != "" ]; then
      if jack_control status; then
        
        if ray_control script_user_action "Jack is already running. If you choose ignore, the jack server will be restarted. Otherwise the session will stop loading."; then
          echo "The session load has been aborted by user."
          ray_control script_info "The session load has been aborted by user."
          exit 0
        else
          restart_server_with_session_settings
        fi
      else
        restart_server_with_session_settings
      fi
    else
      echo "jack_settings.env is not complete so ignoring it !"
    fi
  else      
    if jack_control status; then
      
      if ray_control script_user_action "The jack server is not started ! Please start it using qjackctl (or other software). Do you want to stop loading the session ?"; then
        echo "The session load has been aborted by user."
        ray_control script_info "The session load has been aborted by user."
        exit 0
      fi
    fi
  fi-->
fi

# CHECK FOR ADDITIONNAL AUDIO DEVICES DEFINED IN THE SETUP IF anyway
#if 'alsa_devices' in $data and len($data['alsa_devices']) > 0
if [ \$CHECK_ADDITIONNAL_AUDIO_DEVICES -eq 1 ]
then
  echo "Check that additionnal devices are available ..."
  COUNT=0
  MISSING_DEVICES=""
#for $device in $data['alsa_devices']
  if [ "\$(cat /proc/asound/cards | grep "$device")" == "" ]
  then
      MISSING_DEVICES="\$MISSING_DEVICES $device"
      COUNT=\$(( COUNT + 1 ))
  fi
#end for

  if [ "\$MISSING_DEVICES" != "" ]
  then
      if [ \$COUNT -gt 1 ]
      then
        ray_control script_user_action "\$MISSING_DEVICES audio devices are missing on this system. (They are used by this RaySession). Do you want to stop loading the session ?"
      else
        ray_control script_user_action "\$MISSING_DEVICES audio device is missing on this system. (It is used by this RaySession). Do you want to stop loading the session ?"
      fi
      if [ $? -eq 0 ]
      then
        echo "The session load has been aborted by user."
        ray_control script_info "The session load has been aborted by user."
        exit 0
      fi
  fi
fi
#end if

# CHECK THE PROGRAM USED BY THIS SESSION
if [ \$CHECK_PROGRAMS -eq 1 ]
then
  echo "Check that program are available on the system ..."
  MISSING_PROGRAMS=""
  COUNT=0

  <xsl:for-each select="//requires">
  if [ "\$(which "<xsl:value-of select="@executable"/>")" == "" ]
  then
      MISSING_PROGRAMS="\$MISSING_PROGRAMS <xsl:value-of select="@executable"/>"
      COUNT=\$(( COUNT + 1 ))
  fi
  </xsl:for-each>

  if [ "\$MISSING_PROGRAMS" != "" ]
  then
      if [ \$COUNT -gt 1 ]
      then
        ray_control script_user_action "\$MISSING_PROGRAMS are missing on this system or are not in the PATH. (They are used by this RaySession). Do you want to stop loading the session ?"
      else
        ray_control script_user_action "\$MISSING_PROGRAMS is missing on this system or is not in the PATH. (It is used by this RaySession). Do you want to stop loading the session ?"      
      fi
      if [ $? -eq 0 ]
      then
        echo "The session load has been aborted by user."
        ray_control script_info "The session load has been aborted by user."
        exit 0
      fi
  fi
fi

if [ \$USE_CATIA -eq 1 ]
then
  mkdir -p /tmp/catia
  RAY_SESSION_NAME="\$(basename "\$RAY_SESSION_PATH")"
  echo "RAY_SESSION_PATH: \$RAY_SESSION_PATH"
  echo "RAY_SESSION_NAME: \$RAY_SESSION_NAME"
  cp "\$RAY_SESSION_PATH/default/metadata-jackclients.yml" "/tmp/catia/\${RAY_SESSION_NAME}.yml" || exit 1
fi


# set this var true if you want all running clients to stop (see top of this file).
clear_all_clients=false

if \$clear_all_clients;then
    ray_control script_info "Clearing clients..."
    ray_control clear_clients
    ray_control hide_script_info
fi

# order daemon to load the session
ray_control run_step


# script here some actions to run once the session is loaded.

</xsl:template>
</xsl:stylesheet>