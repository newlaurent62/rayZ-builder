<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">#!/bin/bash
#
# $1 : new_session_name
# $2 : copy the fill in config files to the new raysession name
# $3 : gui | nogui : start the raysession gui at the end of the creation process

clientCount=0

function create_clientID() {


  ACTION="\$1"
  PROGRAM="\$2"
  
  if [ "\$clientCount" == "" ]; then
    echo "clientCount must not be empty !"
    exit 1
  fi
  
  case "\$SESSION_MANAGER" in
    ray_control)
      echo "__ create client ID __"  
      echo "set clientID using ray_control"
      if [ "\$ACTION" == "add_executable" ]
      then
        clientID=\$(ray_control \$ACTION "\$PROGRAM" not_start)
        if [ \$? -ne 0 ]
        then
          echo -e "\e[1m\e[31mCould not create proxy with ray_control !\e[0m"
          exit 1
        fi      
      elif [ "\$ACTION" == "add_proxy" ]
      then
        clientID=\$(ray_control add_executable "\$PROGRAM" via_proxy not_start)
        if [ \$? -ne 0 ]
        then
          echo -e "\e[1m\e[31mCould not create proxy with ray_control !\e[0m"
          exit 1
        fi
      else
        echo -e "\e[1m\e[31mUnknown action '\$ACTION' !\e[0m"
        exit 1
      fi
    ;;
    ray_xml)
      echo "set clientID with rayZ generation"
      clientCount=\$(( clientCount + 1 ))
      clientID="\${clientCount}_\$PROGRAM" 
    ;;
    nsm)
      echo "set clientID with rayZ generation"
      clientCount=\$(( clientCount + 1 ))
      clientID="\${clientCount}_\$PROGRAM"    
    ;;
    *)
      echo "Unknown session manager '\$SESSION_MANAGER' !"
      exit 1
    ;;
  esac
}

function create_proxy() {
  
  echo "__ create proxy __ (\$clientID)"
  
  description=""
  wait_window=0
  config_file=""
  no_save_level=2
  arguments=""
  executable="alt-config-session"
  stop_signal=15
  save_signal=0
  
  if [ "\$session_path" == "" ]
  then
    echo -e "\e[1m\e[31mThe session_path must be set !\e[0m"
    exit 1
  fi

  if [ "\$session_name" == "" ]
  then
    echo -e "\e[1m\e[31mThe session_name must be set !\e[0m"
    exit 1
  fi

  if [ "\$clientID" == "" ]
  then
    echo -e "\e[1m\e[31mThe clientID must be set !\e[0m"
    exit 1
  fi

  case "\$SESSION_MANAGER" in  
  ray_control)
    echo "- ray_control proxy"
    executable="ray-config-session"
    ;;
  ray_xml)
    echo "- ray_xml proxy"
    executable="ray-config-session"
    ;;
  nsm)
    echo "- nsm proxy"
    executable="nsm-config-session"
    ;;
  *)
      echo "Unknown session manager '\$SESSION_MANAGER' !"
      exit 1
    ;;
  esac
  
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
      exit 1
      ;;
    esac
  done
    
  case "\$SESSION_MANAGER" in
    ray_control)      
      mkdir -p "\$session_path/\$session_name.\$clientID"
      ray_control client \$clientID set_proxy_properties wait_window:"\$wait_window" config_file:"\$config_file" no_save_level:"\$no_save_level" arguments:"\$arguments" save_signal:"\$save_signal" executable:"\$executable" stop_signal:"\$stop_signal"
      if [ $? -ne 0 ]
      then
        echo -e "\e[1m\e[31mCan't set the proxy properties with ray_control on '\$clientID'\e[0m"
        error
      fi
      ;;
    ray_xml)
      arguments="\${arguments//\"/&amp;quot;}"
      arguments="\${arguments//\&amp;/&amp;amp;}"
      arguments="\${arguments//\'/&amp;apos;}"
      arguments="\${arguments//&lt;/&amp;lt;}"
      arguments="\${arguments//&gt;/&amp;gt;}"
      mkdir -p "\$session_path/\$session_name.\$clientID"
      cat&lt;&lt;EOF_rayproxy_xml_2 &gt; "\$session_path/\$session_name.\$clientID/ray-proxy.xml" || exit 1
<![CDATA[<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE RAY-PROXY>
<RAY-PROXY wait_window="\$wait_window" config_file="\$config_file" no_save_level="\$no_save_level" arguments="\$arguments" VERSION="0.9.0" save_signal="\$save_signal" executable="\$executable" stop_signal="\$stop_signal"/>
]]>
EOF_rayproxy_xml_2
      ;;
    nsm)
      mkdir -p "\$session_path/NSM Proxy.\$clientID"
      cat&lt;&lt;EOF_nsmproxy &gt; "\$session_path/NSM Proxy.\$clientID/nsm-proxy.config"
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
EOF_nsmproxy
      ;;
    *)
      echo "unknown session-manager paramater '\$SESSION_MANAGER' error in create_proxy"
      exit 1
      ;;
  esac
}

function set_session_root_and_path() {

  case "\$SESSION_MANAGER" in
    ray_control)
      ray_control quit
      echo "-------- Starting new ray daemon "
      export RAY_CONTROL_PORT=\$(ray_control start_new ) || error
      RAY_SESSION_ROOT="\$(ray_control get_root)" || error
      
      echo "RAY_SESSION_ROOT: '\$RAY_SESSION_ROOT'"
      session_root=\${RAY_SESSION_ROOT:-\$HOME/Ray Sessions}

      # We don't create the session_path ray_control creates it
      ;;
    ray_xml)      
      echo "RAY_SESSION_ROOT: '\$RAY_SESSION_ROOT'"
      session_root=\${RAY_SESSION_ROOT:-\$HOME/Ray Sessions}
      ;;
    nsm)
      echo "NSM_SESSION_ROOT: '\$NSM_SESSION_ROOT'"  
      session_root=\${NSM_SESSION_ROOT:-\$HOME/NSM Sessions}
      ;;
    *)
      echo "unknown session-manager '\$SESSION_MANAGER' error in set_session_root_and_path"
      exit 1
      ;;
  esac
  
  echo "SESSION_ROOT : '\$session_root'"
  session_root="\${session_root//\"}"

  if [ ! -d "\$session_root" ]; then
    echo "'\$session_root' is not a directory ! Please create this directory first."
    error
  fi

  session_path="\$session_root/\$session_name"
  echo "SESSION_PATH : '\$session_path'"
  
  session_path="\${session_path//\"}"
  if [ -d "\$session_path" ]; then
    echo "The directory '\$session_path' already exists !"
    error
  fi
}

function create_dir_in_client() {

  case "\$SESSION_MANAGER" in
    ray_control)
      dir="\$session_path/\$session_name.\$clientID/\$1"
      mkdir -p "\$dir" || error
      echo "\$dir created"
      ;;
    ray_xml)
      dir="\$session_path/\$session_name.\$clientID/\$1"
      mkdir -p "\$dir" || error
      echo "\$dir created"
      ;;
    nsm)
      dir="\$session_path/NSM Proxy.\$clientID/\$1"
      mkdir -p "\$dir" || error
      echo "\$dir created"
      ;;
    *)
      echo "unknown session-manager '\$SESSION_MANAGER' error in create_dir_in_client"
      exit 1
      ;;
  esac

}

function copy_to_client_dir () {

  if [ "\$1" == "" -o "\$2" == "" ]; then
    echo "Error the files or dirs to copy is/are empty (copy_to_client_dir)!"
    exit 1
  fi

  case "\$SESSION_MANAGER" in
    ray_control)
      dirfile="\$session_path/\$session_name.\$clientID/\$2"
      mkdir -p "\$(dirname "\$dirfile")" || error
      echo "\$dir created"
      ;;
    ray_xml)
      dirfile="\$session_path/\$session_name.\$clientID/\$2"
      mkdir -p "\$(dirname "\$dirfile")" || error
      echo "\$dir created"
      ;;
    nsm)
      dirfile="\$session_path/NSM Proxy.\$clientID/\$2"
      mkdir -p "\$(dirname "\$dirfile")" || error
      echo "\$dir created"
      ;;
    *)
      echo "unknown session-manager '\$SESSION_MANAGER' error in copy_to_client_dir"
      exit 1
      ;;
  esac
  
  echo "Copying file(s) to \$2" 
  cp -rf "\$1" "\$dirfile" || error
  
  
}
function set_client_properties() {
  echo "__ Set client properties __ (\$clientID)"
  launched=0
  description=""
  icon=""
  label=""
  if [ "\$ACTION" == "add_proxy" ];then
    if [ "\$SESSION_MANAGER" == "nsm" ];then
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

  if [ "\$clientID" == "" ]
  then
    echo -e "\e[1m\e[31mThe clientID must be set !\e[0m"
    exit 1
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
      exit 1
      ;;
    esac
  done

  case "\$SESSION_MANAGER" in
    ray_control)
      ray_control client \$clientID set_properties launched:"\$launched" icon:"\$icon" label:"\$label" executable:"\$executable" icon:"\$icon" name:"\$name" 
      if [ \$? -ne 0 ]
      then
        echo -e "\e[1m\e[31mCould not set properties !\e[0m"
        exit 1
      fi
      ray_control client \$clientID set_description "\$description"
      ;;
    ray_xml)
      cat &lt;&lt; EOF_raysession_xml &gt;&gt; "\$session_path/raysession.xml"
&lt;client id="\$clientID" description="\$description" launched="\$launched" label="\$label" icon="\$icon" description="\$description"  executable="\$executable" name="\$name"/&gt;
EOF_raysession_xml
      ;;
    nsm)
      if [ "\$ACTION" == "add_proxy" ];then
      
        cat &lt;&lt; EOF_nsmsession_proxy &gt;&gt; "\$session_path/session.nsm"
\$name:nsm-proxy:\$clientID
EOF_nsmsession_proxy

      else

        cat &lt;&lt; EOF_nsmsession_exec &gt;&gt; "\$session_path/session.nsm"
\$name:\$executable:\$clientID
EOF_nsmsession_exec

      fi
      ;;
    *)
      echo "unknown session-manager '\$SESSION_MANAGER' error in set_client_properties"
      exit 1
      ;;
  esac

}

function set_jackclient_properties() {
  
  jackclientname=""
  windowtitle=""
  layer="RaySession - \$session_name"
  guitoload=""
  
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
      exit 1
      ;;
    esac
  done


  echo "__ set_jackclient_properties __ ( \$jackclientname ) : windowtitle: \$windowtitle, layer: \$layer"
  
  echo "    - name:          \$jackclientname" &gt;&gt; "\$session_path/default/metadata-jackclients.yml"
  echo "      windowtitle:   \$windowtitle" &gt;&gt; "\$session_path/default/metadata-jackclients.yml"
  echo "      layer:         \$layer" &gt;&gt; "\$session_path/default/metadata-jackclients.yml"
  echo "      guitoload:     \$guitoload" &gt;&gt; "\$session_path/default/metadata-jackclients.yml"
  echo "      clientid:      \$clientID" &gt;&gt; "\$session_path/default/metadata-jackclients.yml"
  
  echo "" &gt;&gt; "\$session_path/default/metadata-jackclients.yml"

}

function init_session() {

  case "\$SESSION_MANAGER" in
    ray_control)
      echo "-------- Create new session named \$session_name"
      ray_control new_session "\$session_name"  || error

      session_path="\$(ray_control get_session_path)" || error
      
      ray_control add_executable ray-jackpatch no_start
      
      ;;
    ray_xml)
      mkdir -p "\$session_path" || error
      cat &lt;&lt; EOF_raysession_init &gt; "\$session_path/raysession.xml" || error 
&lt;RAYSESSION VERSION="0.8.3" name="\$session_name"&gt;
&lt;Clients&gt;
  &lt;client icon="curve-connector" description="load/save the jack connections." executable="ray-jackpatch" launched="1" id="patch" name="JACK Patch Memory"/&gt;
EOF_raysession_init
      
      ;;
    nsm)
      mkdir -p "\$session_path" || error
      echo "JACKPatch:jackpatch:0_patch" &gt; "\$session_path/session.nsm" || error
    ;;
    *)
      echo "unknown session-manager '\$1' error in init_session"
      exit 1
      ;;
  esac
  
  ## copy filltemplate_dir (e.g. directory containing all default config files) to session_path
  if [ ! -d "\$filltemplate_dir" ]
  then
    echo -e "\e[1m\e[31mThe '\$filltemplate_dir' is not a directory !\e[0m"
    exit 1
  fi

  cp -r "\$filltemplate_dir/default" "\$session_path/" || error
  echo "-------- default dir copied"
  
  echo  "sessionname:  \$session_name" &gt; "\$session_path/default/metadata-jackclients.yml"
  echo  "jackclients:" &gt;&gt; "\$session_path/default/metadata-jackclients.yml"
  
}

function ray_patch() {
  filename="\$session_path/\$session_name.patch.xml"
  echo "-------- Install patch.xml to '\$filename'"
  cp "\$filltemplate_dir/default/patch.xml" "\$filename" || error
  cp "\$filltemplate_dir/default/patch.xml" "\$session_path/default/\$session_name.patch.xml" || error

  if [ "\$SESSION_MANAGER" == ray* -a -d "\$filltemplate_dir/ray-scripts" ];then
    dir="\$session_path/ray-scripts"
    echo "-------- Copy ray-scripts to '\$dir'"
    cp -r "\$filltemplate_dir/ray-scripts" "\$dir" || error
  fi
}

function ray_scripts() {
  cp -r "\$filltemplate_dir/ray-scripts" "\$session_path/ray-scripts"

  echo "CHECK_JACK=1" >> "\$session_path/ray-scripts/.env" || error
  echo "CHECK_ADDITIONNAL_AUDIO_DEVICES=1" >> "\$session_path/ray-scripts/.env" || error
  echo "CHECK_SERVER=1" > "\$session_path/ray-scripts/.env" || error
  echo "CHECK_PROGRAMS=1" >> "\$session_path/ray-scripts/.env" || error
}

function end_session() {

  case "\$SESSION_MANAGER" in
    ray_control)
      
      echo "-------- Save and close the session"
      ray_control close || error

      ray_patch

      ray_scripts
      
      echo "-------- Copy raysession.xml to 'default/raysession.xml.backup'"
      filename="\$session_path/raysession.xml"
      cp "\$filename" "\$session_path/default/raysession.xml.backup" || error

      ray_control quit || error
      echo -e "\e[1m\e[32mRay Session '\$session_name' in '\$session_path' created successfully.\e[0m"

      ;;
    ray_xml)
      cat &lt;&lt; EOF_raysession_end &gt;&gt; "\$session_path/raysession.xml"
<![CDATA[</Clients>
<RemovedClients/>
<Windows/>
</RAYSESSION>]]>
EOF_raysession_end
      
      ray_patch

      ray_scripts

      echo "-------- Copy raysession.xml to 'default/raysession.xml.backup'"
      filename="\$session_path/raysession.xml"
      cp "\$filename" "\$session_path/default/raysession.xml.backup" || error


      echo -e "\e[1m\e[32mRay Session '\$session_name' in '\$session_path' created successfully.\e[0m"
  
      
      ;;
    nsm)
      echo -e "\e[1m\e[32mNSM Session '\$session_name' in '\$session_path' created successfully.\e[0m"

      cp "\$filltemplate_dir/default/nsm_patch.jackpatch" "\$session_path/JACKPatch.0_patch.jackpatch" || error
      cp "\$filltemplate_dir/default/nsm_patch.jackpatch" "\$session_path/default/JACKPatch.0_patch.jackpatch" || error
      ;;
    *)
      echo "unknown session-manager '\$SESSION_MANAGER' error in end_session"
      exit 1
      ;;
  esac
}

function gui_session() {
  if [ "\$startgui" == "gui" ];then
    case "\$SESSION_MANAGER" in
      ray_control)
        raysession --session="\$session_name" &amp;
        ;;
      ray_xml)
        raysession --session="\$session_name" &amp;
        ;;
      nsm)
        non-session-manager &amp;
        ;;
      *)
        echo "unknown session-manager '\$SESSION_MANAGER' error in gui_session"
        exit 1
        ;;
    esac
  fi
}


function error() {
  echo -e "\e[1m\e[31mAn error occured. See log above.\e[0m"
  if [ "\$SESSION_MANAGER" == "ray_control" ]; then
    ray_control script_info "An error occured during the raysession creation ! (see logs for more details)"
    if [ "\$RAY_CONTROL_PORT" != "" ]
    then
      ray_control quit  
      ray_control stop
    fi
  fi
  exit 1
}

if [ $# -ne 4 ]
then
  echo "Usage:"
  echo "  session.sh NEW_RAYSESSION_NAME TEMPLATE_DIR ray_control|ray_xml|nsm gui|nogui"
  exit 1
fi

session_name="\$1"
filltemplate_dir="\$2"
startgui="\$4"
SESSION_MANAGER="\$3"

set_session_root_and_path

echo "------ filltemplate_dir: \$filltemplate_dir"
echo "------ session_path: \$session_path"
echo "------ \$startgui"
echo "------ \$SESSION_MANAGER"

init_session

# these jack client don't belong to RaySession
set_jackclient_properties --jackclientname "PulseAudio JACK Source" --windowtitle "pavucontrol" --guitoload "pavucontrol" --layer ""
set_jackclient_properties --jackclientname "PulseAudio JACK Sink" --windowtitle "pavucontrol" --guitoload "pavucontrol" --layer ""

# these jack client don't belong to RaySession
set_jackclient_properties --jackclientname "system" --windowtitle "pavucontrol" --guitoload "pavucontrol" --layer ""

<xsl:for-each select="//template-snippet[@ref-id='session_sh']">
#[FROM] TEMPLATE SNIPPET Page id: <xsl:value-of select="../@id"/>
echo "-------- adding page '<xsl:value-of select="../@id"/>'"
<xsl:value-of select="."/>

#[/FROM] TEMPLATE SNIPPET Page id: <xsl:value-of select="../@id"/>
</xsl:for-each>

if [ "\$SESSION_MANAGER" == "nsm" ]; then
  note_file="README"
else
  note_file="ray-notes"
fi

cat&lt;&lt;EOF_Notes &gt; "\$session_path/\$note_file"
<xsl:value-of select="info/title"/>

author:        <xsl:value-of select="info/author"/>
version:       v<xsl:value-of select="info/version"/>
category:      <xsl:value-of select="info/category"/>
keywords:      <xsl:value-of select="info/keywords"/>

Resume:
<xsl:value-of select="info/description"/>

Created by rayZ-builder
EOF_Notes

end_session

gui_session


</xsl:template>
</xsl:stylesheet>
