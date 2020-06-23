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
CHECK_SERVER=true
USE_JACK=true
USE_JACK_SETTINGS=false
CHECK_ADDITIONNAL_AUDIO_DEVICES=true
CHECK_PROGRAMS=true
RAY_HOSTNAME_SENSIBLE=false

if [ -f "\$RAY_SCRIPTS_DIR/.env" ]; then
  source "\$RAY_SCRIPTS_DIR/.env"
fi

export RAY_HOSTNAME_SENSIBLE

# [/VARIABLES]

function check_server_running() {
  if [ "\$(which systemctl)" != "" ]
  then
    SERVICE="\$(systemctl --all --type service | grep "\$1" | awk '{print \$1}')"
    if [ "\$SERVICE" != "" ];then
        echo "\$1 has been found in systemd."
        if [ "\$(systemctl status \$SERVICE | grep "active (running)")" == "" ]
        then
          
          if ray_control script_user_action "It seems that \$1 is not running in systemd. This session use it. Please start it using 'sudo systemctl start \$SERVICE'. Do you want to stop loading the session ?"; then
            echo "The session load has been aborted by the user."
            ray_control script_info "The session load has been aborted by the user."
            exit 0
          fi
        fi
    else
        echo "\$1 does not exist in systemd."
        if ray_control script_user_action "It seems that \$1 is not installed in systemd. This session use it. Please install it. Do you want to stop loading the session ?"; then
          echo "The session load has been aborted by the user."
          ray_control script_info "The session load has been aborted by the user."
          exit 0
        fi
    fi
  fi
}

# CHECK THE PROGRAMS USED BY THIS SESSION
if \$CHECK_PROGRAMS; then
  echo -e "\e[1mCheck that executable(s) are available on the system ...\e[0m"
  missing_executables=""
  count=0
  
  previous_path="\$PATH"
  <xsl:for-each select="//requires">
    <xsl:choose>
      <xsl:when test="ancestor::page/@section-name">
#set section = "<xsl:value-of select="../@section-name"/>"
      </xsl:when>
      <xsl:otherwise>
#set section = None
      </xsl:otherwise>
    </xsl:choose>
#if not section or section in $data['wizard.sectionnamelist']:
  export PATH="\$RAY_SESSION_PATH/.local/bin:\$PATH"
  executable="<xsl:value-of select="@executable"/>"
  if [ "\$(which "\$executable")" == "" ]
  then
    echo -e "\e[31m\$executable has not been found.\e[0m"
    missing_executables="\$missing_executables <xsl:value-of select="@executable"/>"
    count=\$(( count + 1 ))
  else
    echo "\$executable has been found in \$(which "\$executable")."
  fi
  export PATH="\$previous_path"
#end if
  </xsl:for-each>
  
  if [ "\$missing_executables" != "" ]
  then
    if [ \$count -gt 1 ]
    then
      ray_control script_user_action "\$missing_executables are missing on this system or are not in the PATH. They are used by this session. Do you want to stop loading the session ?"
    else
      ray_control script_user_action "\$missing_executables is missing on this system or is not in the PATH. It is used by this session. Do you want to stop loading the session ?"      
    fi
    if [ $? -eq 0 ]
    then
      echo "The session load has been aborted by the user."
      ray_control script_info "The session load has been aborted by the user."
      exit 0
    fi
  else
    echo -e "\e[32mAll executables have been found.\e[0m"
  fi
fi

if \$USE_JACK; then
  echo -e "\e[1mCheck Jack server ...\e[0m"
  if \$USE_JACK_SETTINGS; then
    if jack_control status &gt;/dev/null 2&gt;&amp;1; then
      DIFF_JACK_PARAM="\$(ray-jack_config_script get_diff)"
      if [ "\$DIFF_JACK_PARAM" != "" ]; then
        if ray_control script_user_action "The jack settings of this ray session differs from the current jack settings ! If you choose ignore, the jack server will be restarted with the jack settings of this ray session otherwise if you click Yes, the session load will be stopped. Your choice ?"; then
            echo "The session load has been aborted by the user."
            ray_control script_info "The session load has been aborted by the user."
            exit 0
        fi    
      else
        echo "Jack settings : no diff between current and session declared jack server parameters."
      fi
    fi
    ray-jack_config_script load || exit 0
    echo "Jack settings loaded."
    ray_control hide_script_info    
  else
    jack_control status &gt;/dev/null 2&gt;&amp;1
    if [ $? -ne 0 ]; then      
      if ray_control script_user_action 'The jack server is not started ! Please start it using qjackctl or other software. Do you want to stop loading the session ?'; then
        echo "The session load has been aborted by the user."
        ray_control script_info "The session load has been aborted by the user."
        exit 0
      fi
    fi
  fi
  if jack_control status &gt;/dev/null 2&gt;&amp;1; then
    echo -e "\e[32mJack is running.\e[0m"
  else
    echo -e "\e[31mJack is not running.\e[0m"
  fi
fi

# CHECK FOR ADDITIONNAL AUDIO DEVICES DEFINED IN THE SETUP IF anyway
#if 'alsa_devices' in $data and len($data['alsa_devices']) > 0
if \$CHECK_ADDITIONNAL_AUDIO_DEVICES; then
  echo -e "\e[1mCheck that additionnal device(s) are available ...\e[0m"
  count=0
  missing_devices=""
#for $device in $data['alsa_devices']
  if [ "\$(cat /proc/asound/cards | grep "$device")" == "" ]
  then
      missing_devices="\$missing_devices $device"
      count=\$(( count + 1 ))
  fi
#end for

  if [ "\$missing_devices" != "" ]
  then
      if [ \$count -gt 1 ]
      then
        echo -e "\e[31mMissing device \$missing_devices\e[0m"
        ray_control script_user_action "\$missing_devices audio devices are missing on this system. They are used by this session. Do you want to stop loading the session ?"
      else
        echo -e "\e[31mMissing devices \$missing_devices\e[0m"
        ray_control script_user_action "\$missing_devices audio device is missing on this system. It is used by this session. Do you want to stop loading the session ?"
      fi
      if [ $? -eq 0 ]
      then
        echo "The session load has been aborted by the user."
        ray_control script_info "The session load has been aborted by the user."
        exit 0
      fi
  fi
fi
#end if

<xsl:apply-templates select='//template-snippet[@ref-id="ray_script_load_sh"]' mode="copy-no-namespaces"/>

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

<xsl:template match="*" mode="copy-no-namespaces"><xsl:element name="{local-name()}"><xsl:copy-of select="@*"/><xsl:apply-templates select="node()" mode="copy-no-namespaces"/></xsl:element></xsl:template>

<xsl:template match="comment()| processing-instruction()" mode="copy-no-namespaces"><xsl:copy/></xsl:template>

</xsl:stylesheet>
