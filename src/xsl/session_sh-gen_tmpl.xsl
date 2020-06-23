<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/session">#!/bin/bash
# Parameters
session_name="\$1"
filltemplate_dir="\$2"
session_manager="\$3"
startgui="\$4"
rayZ_templatedir="\$5"
debug="\$6"

clientCount=0


function debug_info() {
  if [ "\$1" == "debug" ]
  then
    exec 4&lt;&gt; /dev/stdout
  else
    exec 4&lt;&gt; /dev/null
  fi
}

function close_debug_info() {
  exec 4&gt;&amp;-
}

######
# 1 : template id
# 2 : data
# 3 : destination file
function generate_file_from_template() {
python3 &lt;&lt;EOF_python_template &gt;&amp;4
import sys
import os
sys.path.append("\$rayZ_templatedir")
from \$1 import \$1

t = \$1()
t.data = \$2
destfilepath = '\$session_path' + os.sep + '\$3'
os.makedirs(os.path.dirname(destfilepath),exist_ok=True)    

f = open(destfilepath,"w+")
content=str(t)
f.write(content)
f.close()
EOF_python_template
}



function generate_nsm_clientID() {
python3 &lt;&lt;EOF_python_nsm
import random
import string
client_id = 'n'
for l in range(4):
    client_id += random.choice(string.ascii_uppercase)
print (client_id)
EOF_python_nsm
}

function command_from() {
python&lt;&lt;EOF_python_cmd
import shlex

print (shlex.split('\$1')[0])
EOF_python_cmd
}

function create_clientID() {


  ACTION="\$1"
  PROGRAM="\$2"
  label="\$3"
  
  if [ "\$clientCount" == "" ]; then
    echo "clientCount must not be empty !"
    error
  fi
  
  case "\$session_manager" in
    ray_control)
      echo "__ create client ID __ (using ray_control)"  &gt;&amp;4
      if [ "\$ACTION" == "add_executable" ]
      then
        clientID=\$(ray_control \$ACTION "\$PROGRAM" not_start 2&gt;/dev/null)
        if [ \$? -ne 0 ]
        then
          echo -e "\e[1m\e[31mCould not create proxy with ray_control !\e[0m"
          error
        fi      
      elif [ "\$ACTION" == "add_proxy" ]
      then
        clientID=\$(ray_control add_executable "\$PROGRAM" via_proxy not_start 2&gt;/dev/null)
        if [ \$? -ne 0 ]
        then
          echo -e "\e[1m\e[31mCould not create proxy with ray_control !\e[0m"
          error
        fi
      else
        echo -e "\e[1m\e[31mUnknown action '\$ACTION' !\e[0m"
        error
      fi
      shortclientID="\$(generate_nsm_clientID)"
    ;;
    nsm)
      echo "__ create client ID __ (using nsm like ID)"  &gt;&amp;4
      clientCount=\$(( clientCount + 1 ))
      clientID="\$(generate_nsm_clientID)"
      shortclientID="\$clientID"
    ;;
    *)
      echo "Unknown session manager '\$session_manager' !"
      error
    ;;
  esac
}

function create_proxy() {
  
  echo "__ create proxy __ (\$clientID)" &gt;&amp;4
  
  description=""
  wait_window=0
  config_file=""
  no_save_level=2
  arguments=""
  executable=""
  stop_signal=15
  save_signal=0
  xdg_config_home=""
  wrapper=""

  if [ "\$session_path" == "" ]
  then
    echo -e "\e[1m\e[31mThe session_path must be set !\e[0m"
    error
  fi

  if [ "\$session_name" == "" ]
  then
    echo -e "\e[1m\e[31mThe session_name must be set !\e[0m"
    error
  fi

  if [ "\$clientID" == "" ]
  then
    echo -e "\e[1m\e[31mThe clientID must be set !\e[0m"
    error
  fi

  while [ \$# -gt 0 ]; do  
    case "\$1" in
    --label)
      v="\${1#??}"
      declare -g \$v="\$2"
      # echo "\$1='\$2'"
      shift 2
      ;;
    
    --*)
      v="\${1#??}"
      declare \$v="\$2"
      # echo "\$1='\$2'"
      shift 2
      ;;
    *)
      echo "unrecognized arg '$1' ... "
      error
      ;;
    esac
  done

  if [ "\$label" == "" ]; then
    echo -e "\e[1m\e[31mThe label must be set ! clientID: '\$clientID'\e[0m"
    error
  fi

  case "\$session_manager" in
    ray_control)      
      mkdir -p "\$session_path/\$session_name.\$clientID"
      if [ "\$xdg_config_home" == "" ]; then
        ray_control client \$clientID set_proxy_properties wait_window:"\$wait_window" \
              config_file:"\$config_file" \
              no_save_level:"\$no_save_level" \
              arguments:"\$arguments" \
              save_signal:"\$save_signal" \
              executable:"\$executable" \
              stop_signal:"\$stop_signal" 2&gt;/dev/null
      else
        wrapper=ray-config-session
        ray_control client \$clientID set_proxy_properties wait_window:"\$wait_window" \
              config_file:"\$config_file" \
              no_save_level:"\$no_save_level" \
              arguments:"--xdg-config-home \"\$xdg_config_home\" -- \$executable \$arguments" \
              save_signal:"\$save_signal" \
              executable:"ray-config-session" \
              stop_signal:"\$stop_signal" 2&gt;/dev/null
      fi
      proxy_dir="\$session_name.\$clientID"
      if [ $? -ne 0 ]
      then
        echo -e "\e[1m\e[31mCan't set the proxy properties with ray_control on '\$clientID'\e[0m"
        error
      fi
      ;;
    nsm)
      label="\${label:-NSM Proxy}"
      proxy_dir="NSM Proxy.\$clientID"
      clientDir="\$session_path/NSM Proxy.\$clientID"
      mkdir -p "\$clientDir"
      ln -rs "\$session_path/\$proxy_dir" "\$session_path/\${label}.\$clientID"

      if [ "\$xdg_config_home" == "" ]; then
        cat&lt;&lt;EOF_nsmproxya &gt; "\$clientDir/nsm-proxy.config"
executable
    \$executable
arguments
    \$arguments
save signal
    \$save_signal
stop signal
    \$stop_signal
label
    \$label
EOF_nsmproxya
      else
        wrapper=nsm-config-session
        cat&lt;&lt;EOF_nsmproxyb &gt; "\$clientDir/nsm-proxy.config"
executable
    nsm-config-session
arguments
    --xdg-config-home "\$xdg_config_home" -- \$executable \$arguments
save signal
    \$save_signal
stop signal
    \$stop_signal
label
    \$label
EOF_nsmproxyb

      fi
      ;;
    *)
      echo "unknown session-manager paramater '\$session_manager' error in create_proxy"
      error
      ;;
  esac
}

function set_session_root_and_path() {

  case "\$session_manager" in
    ray_control)
      ray_control quit &gt;&amp;4 2&gt;/dev/null
      echo "-------- Starting new ray daemon " &gt;&amp;4
      export RAY_CONTROL_PORT=\$(ray_control start_new_hidden 2&gt;/dev/null) || error
      RAY_SESSION_ROOT="\$(ray_control get_root 2&gt;/dev/null)" || error
      
      echo "RAY_SESSION_ROOT: '\$RAY_SESSION_ROOT'" &gt;&amp;4
      session_root=\${RAY_SESSION_ROOT:-\$HOME/Ray Sessions}

      # We don't create the session_path ray_control creates it
      ;;
    nsm)
      echo "NSM_SESSION_ROOT: '\$NSM_SESSION_ROOT'"   &gt;&amp;4
      session_root=\${NSM_SESSION_ROOT:-\$HOME/NSM Sessions}
      ;;
    *)
      echo "unknown session-manager '\$session_manager' error in set_session_root_and_path"
      error
      ;;
  esac
  
  echo "SESSION_ROOT : '\$session_root'" &gt;&amp;4
  session_root="\${session_root//\"}"

  if [ ! -d "\$session_root" ]; then
    echo "'\$session_root' is not a directory ! Please create this directory first."
    error
  fi

  session_path="\$session_root/\$session_name"
  echo "SESSION_PATH : '\$session_path'" &gt;&amp;4
  
  session_path="\${session_path//\"}"
  if [ -d "\$session_path" ]; then
    echo "The directory '\$session_path' already exists !"
    error
  fi
}

function create_dir_in_client() {

  if [ "\$proxy_dir" == "" ];then
    echo "The proxy dir is empty !"
    error
  fi
  
  case "\$session_manager" in
    ray_control)
      dir="\$session_path/\$proxy_dir/\$1"
      mkdir -p "\$dir" || error
      echo "\$dir created" &gt;&amp;4
      ;;
    nsm)
      dir="\$session_path/\$proxy_dir/\$1"
      mkdir -p "\$dir" || error
      echo "\$dir created" &gt;&amp;4
      ;;
    *)
      echo "unknown session-manager '\$session_manager' error in create_dir_in_client"
      error
      ;;
  esac

}

function copy_to_client_dir () {

  if [ "\$1" == "" -o "\$2" == "" ]; then
    echo "Error the files or dirs to copy is/are empty (copy_to_client_dir)!"
    error
  fi

  if [ "\$proxy_dir" == "" ];then
    echo "The proxy dir is empty !"
    error
  fi

  case "\$session_manager" in
    ray_control)
      dirfile="\$session_path/\$proxy_dir/\$2"
      mkdir -p "\$(dirname "\$dirfile")" || error
      echo "\$dir created" &gt;&amp;4
      ;;
    nsm)
      dirfile="\$session_path/\$proxy_dir/\$2"
      mkdir -p "\$(dirname "\$dirfile")" || error
      echo "\$dir created" &gt;&amp;4
      ;;
    *)
      echo "unknown session-manager '\$session_manager' error in copy_to_client_dir"
      error
      ;;
  esac
  
  echo "Copying file(s) to \$2" &gt;&amp;4
  cp -rf "\$1" "\$dirfile" || error
  
  
}
function set_client_properties() {
  echo "__ Set client properties __ (\$clientID)" &gt;&amp;4
  launched=0
  description=""
  icon=""
    
  if [ "\$ACTION" == "add_proxy" ];then
    if [ "\$session_manager" == "nsm" ];then
      name="\${name:-NSM PROXY \$PROGRAM}"
      executable="nsm-proxy"
    else
      name="\${name:-RAY PROXY \$PROGRAM}"
      executable="ray-proxy"
    fi
  else
    name="\${name:-\$PROGRAM}"
    executable="\$PROGRAM"
  fi

  if [ "\$label" == "" ]; then
    echo -e "\e[1m\e[31mThe label must set ! clientID: '\$clientID'\e[0m"
    error
  elif [ "\$clientID" == "" ]; then
    echo -e "\e[1m\e[31mThe clientID must set ! (please call create_clientID)\e[0m"
    error
  fi

  while [ \$# -gt 0 ]; do  
    case "\$1" in
    --*)
      v="\${1#??}"
      declare \$v="\$2"
      # echo "\$1='\$2'"
      shift 2
      ;;
    *)
      echo "unrecognized arg '$1' ... "
      error
      ;;
    esac
  done

  if [ "\$label" == "" ]; then
    echo "The label must set ! clientID: '\$clientID'"
    error
  fi

  case "\$session_manager" in
    ray_control)
      ray_control client \$clientID set_properties launched:"\$launched" \
          icon:"\$icon" \
          label:"\$label" \
          executable:"\$executable" \
          icon:"\$icon" \
          name:"\$name" &gt;&amp;4 2&gt;/dev/null

      if [ \$? -ne 0 ]
      then
        echo -e "\e[1m\e[31mCould not set properties ! (\$clientID)\e[0m"
        error
      fi
      
      ray_control client \$clientID set_description "\$description" &gt;&amp;4 2&gt;/dev/null || error
      
      if [ \$? -ne 0 ]
      then
        echo -e "\e[1m\e[31mCould not set description ! (\$clientID)\e[0m"
        error
      fi
      
      ;;
    nsm)
      if [ "\$ACTION" == "add_proxy" ]; then
      
        cat &lt;&lt; EOF_nsmsession_proxy &gt;&gt; "\$session_path/session.nsm"
\$label:nsm-proxy:\$clientID
EOF_nsmsession_proxy

      else

        cat &lt;&lt; EOF_nsmsession_exec &gt;&gt; "\$session_path/session.nsm"
\$name:\$executable:\$clientID
EOF_nsmsession_exec

      fi
      ;;
    *)
      echo "unknown session-manager '\$session_manager' error in set_client_properties"
      error
      ;;
  esac

}

function set_jackclient_properties() {
  
  jackclientname=""
  windowtitle=""
  layer="RaySession - \$session_name"
  guitoload=""
  with_gui="False"
  
  while [ \$# -gt 0 ]; do  
    case "\$1" in
    --*)
      v="\${1#??}"
      declare \$v="\$2"
      # echo "\$1='\$2'"
      shift 2
      ;;
    *)
      echo "unrecognized arg '$1' ... "
      error
      ;;
    esac
  done
  if [ "\$wrapper" != "" ]; then
    clienttype="proxy-wrapper"
  else
    clienttype="\${ACTION#????}"
  fi
  
  echo "__ set_jackclient_properties __ ( \$jackclientname ) : windowtitle: \$windowtitle, layer: \$layer, clienttype: \$clienttype, with_gui: \$with_gui" &gt;&amp;4
  
  if [ "\$layer" != "" -a "\$session_manager" == "ray_control" ]; then
    ray_control client "\$clientID" set_custom_data jacknames "\$jackclientname" &gt;&amp;4 2&gt;/dev/null
    ray_control client "\$clientID" set_custom_data windowtitle "\$windowtitle" &gt;&amp;4 2&gt;/dev/null
    ray_control client "\$clientID" set_custom_data layer "\$layer" &gt;&amp;4 2&gt;/dev/null
    ray_control client "\$clientID" set_custom_data guitoload "\$guitoload" &gt;&amp;4 2&gt;/dev/null
    ray_control client "\$clientID" set_custom_data with_gui "\$with_gui"  &gt;&amp;4 2&gt;/dev/null
    ray_control client "\$clientID" set_custom_data clienttype "\$clienttype" &gt;&amp;4 2&gt;/dev/null
    
  fi
}

function init_session() {
  USE_JACK=true
  USE_JACK_SETTINGS=true
  CHECK_ADDITIONNAL_AUDIO_DEVICES=true
  CHECK_SERVER=true
  CHECK_PROGRAMS=true

  case "\$session_manager" in
    ray_control)
      
      echo "-------- Create new session named \$session_name"
      ray_control new_session "\$session_name"  &gt;&amp;4 2&gt;/dev/null || error

      session_path="\$(ray_control get_session_path 2&gt;/dev/null)" || error

      create_clientID add_executable "ray-jackpatch" "JACK Connections"
      patchID="\$clientID"
      set_client_properties --icon "curve-connector" \
                            --launched 1 \
                            --description "Manage save/restore jack conections." \
                            --name "Jack Patch"
      clientID=""
      ;;
    nsm)
      clientID="\$(generate_nsm_clientID)"
      patchID="\$clientID"
      mkdir -p "\$session_path" || error
      patchLabel="JACKPatch"
      echo "\$patchLabel:jackpatch:\$clientID" &gt; "\$session_path/session.nsm" || error
    ;;
    *)
      echo "unknown session-manager '\$1' error in init_session"
      error
      ;;
  esac
  
  ## copy filltemplate_dir (e.g. directory containing all default config files) to session_path
  if [ ! -d "\$filltemplate_dir" ]
  then
    echo -e "\e[1m\e[31mThe '\$filltemplate_dir' is not a directory !\e[0m"
    error
  fi

  cp -r "\$filltemplate_dir/default" "\$session_path/" || error
  echo "-------- default dir copied" &gt;&amp;4

  cp -r "\$filltemplate_dir/.local" "\$session_path/" || error
  echo "-------- .local dir copied " &gt;&amp;4

  mkdir -p "\$session_path/ray-scripts" || error  
}

function ray_patch() {
  case "\$session_manager" in
    ray_control)
      filename="\$session_path/\$session_name.\$patchID.xml"
      echo "-------- Install patch.xml to '\$filename'" &gt;&amp;4
      cp "\$filltemplate_dir/default/patch.xml" "\$filename" || error
      cp "\$filltemplate_dir/default/patch.xml" "\$session_path/default/\$session_name.\$patchID.xml" || error
      test -f "\$filltemplate_dir/default/jack_parameters" &amp;&amp; cp "\$filltemplate_dir/default/jack_parameters" "\$session_path/jack_parameters" 
      ;;
  esac
}

function ray_scripts() {
  if [ "\$session_manager" == ray_xml -o "\$session_manager" == ray_control ] &amp;&amp; [ -d "\$filltemplate_dir/ray-scripts" ];then
    dir="\$session_path/ray-scripts"
    mkdir -p "\$dir"
    echo "-------- Copy ray-scripts to '\$session_path/'" &gt;&amp;4
    cp "\$filltemplate_dir/ray-scripts/"*.sh "\$session_path/ray-scripts/" || error
    cp "\$filltemplate_dir/ray-scripts/.jack_config_script" "\$session_path/ray-scripts/" || error
  fi

}

function end_session() {

  case "\$session_manager" in
    ray_control)
      
      echo "-------- Save and close the session" &gt;&amp;4
      ray_control close &gt;&amp;4 2&gt;/dev/null || error

      ray_patch

      ray_scripts
      
      echo "-------- Copy raysession.xml to 'default/raysession.xml.backup'" &gt;&amp;4
      filename="\$session_path/raysession.xml"
      cp "\$filename" "\$session_path/default/raysession.xml.backup" || error

      ray_control quit &gt;&amp;4 2&gt;/dev/null || error
      echo -e "\e[1m\e[32mRay Session '\$session_name' in '\$session_path' created successfully.\e[0m"

      ;;
    nsm)
      echo -e "\e[1m\e[32mNSM Session '\$session_name' in '\$session_path' created successfully.\e[0m"

      cp "\$filltemplate_dir/default/nsm_patch.jackpatch" "\$session_path/\$patchLabel.\$patchID.jackpatch" || error
      cp "\$filltemplate_dir/default/nsm_patch.jackpatch" "\$session_path/default/\$patchLabel.\$patchID.jackpatch" || error
      ;;
    *)
      echo "unknown session-manager '\$session_manager' error in end_session"
      error
      ;;
  esac
  
  echo "USE_JACK=\$USE_JACK" &gt; "\$session_path/ray-scripts/.env" || error
  echo "USE_JACK_SETTINGS=\$USE_JACK_SETTINGS" &gt;&gt; "\$session_path/ray-scripts/.env" || error
  echo "CHECK_ADDITIONNAL_AUDIO_DEVICES=\$CHECK_ADDITIONNAL_AUDIO_DEVICES" &gt;&gt; "\$session_path/ray-scripts/.env" || error
  echo "CHECK_SERVER=\$CHECK_SERVER" &gt;&gt; "\$session_path/ray-scripts/.env" || error
  echo "CHECK_PROGRAMS=\$CHECK_PROGRAMS" &gt;&gt; "\$session_path/ray-scripts/.env" || error
}

function gui_session() {
  if [ "\$startgui" == "gui" ];then
    case "\$session_manager" in
      ray_control)
        raysession --session="\$session_name" &amp;
        ;;
      nsm)
        non-session-manager &amp;
        ;;
      *)
        echo "unknown session-manager '\$session_manager' error in gui_session"
        error
        ;;
    esac
  fi
}


function error() {
  echo -e "\e[1m\e[31mAn error occured. See log above.\e[0m"
  if [ "\$session_manager" == "ray_control" ]; then
    ray_control script_info "An error occured during the raysession creation ! (see logs for more details)"
    if [ "\$RAY_CONTROL_PORT" != "" ]
    then
      ray_control quit  
      ray_control stop
    fi
  fi
  close_debug_info
  exit 1
}

################################################################"
# MAIN
#

if [ $# -ne 6 ]
then
  echo "Usage:"
  echo "  session.sh SESSION_NAME TEMPLATE_DIR RAYZ_TEMPLATE_DIR (ray_control|nsm) (gui|nogui) (debug|nodebug)"
  error
fi

session_name="\$1"
filltemplate_dir="\$2"
rayZ_templatedir="\$3"
session_manager="\$4"
startgui="\$5"
debug="\$6"

debug_info "\$debug"

if [ ! -d "\$rayZ_templatedir" ]; then
  echo "'\$rayZ_templatedir' is not a directory !"
  error
fi

if [ ! -d "\$filltemplate_dir" ]; then
  echo "'\$filltemplate_dir' is not a directory !"
  error
fi

set_session_root_and_path

echo "------ rayZ_templatedir: \$rayZ_templatedir"
echo "------ filltemplate_dir: \$filltemplate_dir"
echo "------ session_path: \$session_path"
echo "------ \$startgui"
echo "------ \$session_manager"
echo "------ \$debug"

init_session

# these jack client don't belong to RaySession
set_jackclient_properties --jackclientname "PulseAudio JACK Source" --windowtitle "pavucontrol" --guitoload "pavucontrol" --layer ""
set_jackclient_properties --jackclientname "PulseAudio JACK Sink" --windowtitle "pavucontrol" --guitoload "pavucontrol" --layer ""

# these jack client don't belong to RaySession
set_jackclient_properties --jackclientname "system" --windowtitle "pavucontrol" --guitoload "pavucontrol" --layer ""

<xsl:apply-templates select="page" mode="copy-no-namespaces"/>

if [ "\$session_manager" == "nsm" ]; then
  note_file="README"
else
  note_file="ray-notes"
fi

cat&lt;&lt;EOF_Notes &gt; "\$session_path/\$note_file"
<xsl:value-of select="info/title"/>

author:        <xsl:value-of select="info/author"/>
version:       <xsl:value-of select="info/version"/>
category:      <xsl:value-of select="info/category"/>
keywords:      <xsl:value-of select="info/keywords"/>

Resume:
<xsl:value-of select="info/description"/>

Created by rayZ-builder
EOF_Notes

end_session

gui_session

close_debug_info

</xsl:template>

<xsl:template match="page" mode="copy-no-namespaces">
echo "Begin section:: <xsl:value-of select="section-name"/>" &gt;&amp;4

<xsl:apply-templates mode="copy-no-namespaces"/>

echo "End section:: <xsl:value-of select="section-name"/>" &gt;&amp;4
</xsl:template>

<xsl:template match="script" mode="copy-no-namesapces">
<xsl:value-of select="."/>
</xsl:template>

<xsl:template match="client" mode="copy-no-namespaces">
# assign clientID variable
create_clientID add_proxy "<xsl:value-of select="command"/>" "<xsl:value-of select="label"/>"

# create proxy
create_proxy  --label "<xsl:value-of select="replace(label,'&quot;', '\\&quot;')"/>" \
              --executable "<xsl:value-of select="command"/>" \
              --arguments "<xsl:text> </xsl:text><xsl:value-of select="replace(arguments,'&quot;', '\\&quot;')"/>" \
              --save_signal <xsl:value-of select="@save_signal"/> \
              --stop_signal <xsl:value-of select="@stop_signal"/> \
              --wait_window <xsl:value-of select="@wait_window"/> \
              --no_save_level <xsl:value-of select="@no_save_level"/> \
              --xdg_config_home "<xsl:value-of select="@xdg-config-home"/>"

# set client properties
set_client_properties --icon "<xsl:value-of select="@icon"/>" \
                      --launched <xsl:value-of select="@launched"/> \
                      --description "<xsl:value-of select="replace(description,'&quot;', '\\&quot;')"/>" \
                      --name "<xsl:value-of select="replace(name,'&quot;', '\\&quot;')"/>" \
                      --label "<xsl:value-of select="replace(label,'&quot;', '\\&quot;')"/>"
<xsl:if test="jack-name">
set_jackclient_properties <xsl:text> --jackclientname </xsl:text> "<xsl:for-each select="jack-name"><xsl:if test="position() > 1">;</xsl:if><xsl:value-of select="replace(.,'&quot;', '\\&quot;')"/></xsl:for-each>" \
                          <xsl:text> --windowtitle </xsl:text>"<xsl:value-of select="replace(window-title-regexp,'&quot;', '\\&quot;')"/>" \
                          <xsl:text> --guitoload </xsl:text> "<xsl:value-of select="replace(gui,'&quot;', '\\&quot;')"/>" \
                          <xsl:text> --with_gui </xsl:text> "<xsl:value-of select="@with-gui"/>"
</xsl:if>

<xsl:if test="nsm-protocol/prepare-proxy-dir">
<xsl:apply-templates select="nsm-protocol/prepare-proxy-dir" mode="copy-no-namespaces"/>
</xsl:if>
</xsl:template>

<xsl:template match="section-name" mode="copy-no-namespaces"/>

<xsl:template match="link" mode="copy-no-namespaces">
  ln -rs "\$session_path/<xsl:value-of select="@session-src"/>" "\$session_path/\$proxy_dir/<xsl:value-of select="@proxy-dest"/>"
</xsl:template>

<xsl:template match="copy-file" mode="copy-no-namespaces">
  cp "\$session_path/<xsl:value-of select="@session-src"/>" "\$session_path/\$proxy_dir/<xsl:value-of select="@proxy-dest"/>"
</xsl:template>

<xsl:template match="copy-tree" mode="copy-no-namespaces">
  cp -r "\$session_path/<xsl:value-of select="@session-src"/>" "\$session_path/\$proxy_dir/<xsl:value-of select="@proxy-dest"/>"
</xsl:template>

<xsl:template match="mkdir" mode="copy-no-namespaces">
  mkdir -p "\$session_path/\$proxy_dir/<xsl:value-of select="@proxy-dir"/>"
</xsl:template>

<xsl:template match="script" mode="copy-no-namespaces">
<xsl:value-of select="."/>
</xsl:template>

<xsl:template match="*" mode="copy-no-namespaces"><xsl:element name="{local-name()}"><xsl:copy-of select="@*"/><xsl:apply-templates select="node()" mode="copy-no-namespaces"/></xsl:element></xsl:template>

<xsl:template match="comment()| processing-instruction()" mode="copy-no-namespaces"><xsl:copy/></xsl:template>

</xsl:stylesheet>

