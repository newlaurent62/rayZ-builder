<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">#!/bin/bash
#
# $1 : new_session_name
# $2 : copy the fill in config files to the new raysession name
# $3 : gui | nogui : start the raysession gui at the end of the creation process

function create_clientID() {


  ACTION="\$1"
  PROGRAM="\$2"
  
  case "\$SESSION_MANAGER" in
    ray_control)
      echo "set clientID using ray_control"
      if [ "\$ACTION" != "add_executable" -a "\$ACTION" != "add_proxy" ]
      then
        echo -e "\e[1m\e[31mUnknown action '\$ACTION' !\e[0m"
        exit 1
      fi

      echo "__ create client ID __"  

      clientID=\$(ray_control \$ACTION "\$PROGRAM")
      if [ \$? -ne 0 ]
      then
        echo -e "\e[1m\e[31mCould not create proxy with ray_control !\e[0m"
        exit 1
      fi
    ;;
    ray_xml)
      echo "set clientID with rayZ generation"
      clientCount=\$(( clientCount + 1 ))
      clientID="\$clientCount_\$PROGRAM" 
    ;;
    nsm)
      echo "set clientID with rayZ generation"
      clientCount=\$(( clientCount + 1 ))
      clientID="\$clientCount_\$PROGRAM"    
    ;;
    *)
      echo "Unknown session manager '\$SESSION_MANAGER' !"
      exit 1
    ;;
  esac
}

function create_proxy() {
  
  echo "__ create proxy __"
  
  description=\${description:-}
  wait_window=\${wait_window:-0}
  config_file=\${config_file:-}
  no_save_level=\${no_save_level:-2}
  arguments=\${arguments:-}
  executable=\${executable:-alt-config-session}
  stop_signal=\${stop_signal:-15}
  save_signal=\${save_signal:-0}
  
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
      echo "\$1='\$2'"
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
      cat&lt;&lt;EOF &gt; "\$session_path/\$session_name.\$clientID/ray-proxy.xml" || exit 1
<![CDATA[<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE RAY-PROXY>
<RAY-PROXY wait_window="\$wait_window" config_file="\$config_file" no_save_level="\$no_save_level" arguments="\$arguments" VERSION="0.9.0" save_signal="\$save_signal" executable="\$executable" stop_signal="\$stop_signal"/>
]]>EOF
      ;;
    ray_xml)
        mkdir -p "\$session_path/\$session_name.\$clientID"
      cat&lt;&lt;EOF &gt; "\$session_path/\$session_name.\$clientID/ray-proxy.xml" || exit 1
<![CDATA[<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE RAY-PROXY>
<RAY-PROXY wait_window="\$wait_window" config_file="\$config_file" no_save_level="\$no_save_level" arguments="\$arguments" VERSION="0.9.0" save_signal="\$save_signal" executable="\$executable" stop_signal="\$stop_signal"/>
]]>EOF
      ;;
    nsm)
      mkdir -p "\$session_path/NSM Proxy.\$clientID"
      cat&lt;&lt;EOF_add_proxy &gt; "\$session_path/NSM Proxy.\$clientID/nsm-proxy.config"
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
EOF_add_proxy
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
      session_root="\$(ray_control get_root)" || error
      ;;
    ray_xml)
      session_root="\$RAY_SESSION_ROOT"
      if [ "\$session_root" == "" ]; then
        session_root="/\$HOME/Ray Sessions"
      fi
      ;;
    nsm)
      session_root="\$NSM_SESSION_ROOT"
      if [ "\$session_root" == "" ]; then
        session_root="/\$HOME/NSM Sessions"
      fi
      ;;
    *)
      echo "unknown session-manager '\$SESSION_MANAGER' error in set_client_properties"
      exit 1
      ;;
  esac
  if [ ! -d "\$session_root" ]; then
    mkdir -p "\$session_root" || error
  fi
  session_path="\$session_root/\$session_name"
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
      echo "unknown session-manager '\$SESSION_MANAGER' error in set_client_properties"
      exit 1
      ;;
  esac

}
function set_client_properties() {
  echo "__ Set client properties __"
  launched=\${launched:-0}
  description=\${description:-}
  icon=\${icon:-default}
  label=\${label:-}
  name=\${name:-RAY-PROXY \$executable}

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
      echo "\$1='\$2'"
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
      executable=\${executable:-"ray-proxy"}
      ray_control client \$clientID set_properties launched:"\$launched" icon:"\$icon" label:"\$label" executable:"\$executable" icon:"\$icon" name:"\$name" 
      if [ \$? -ne 0 ]
      then
        echo -e "\e[1m\e[31mCould not set properties !\e[0m"
        exit 1
      fi
      
      ray_control client \$clientID set_description "\$description"
      if [ \$? -ne 0 ]
      then
        echo -e "\e[1m\e[31mCould not set description !\e[0m"
        exit 1
      fi
      
      ;;
    ray_xml)
      executable=\${executable:-"ray-proxy"}
      cat &lt;&lt; EOF &gt;&gt; "\$session_path/raysession.xml"
<client id="\$clientID" launched="\$launched" label="\$label" icon="\$icon" description="\$description"  executable="\$executable" name="\$name"/>
EOF
      ;;
    nsm)
      if [ "\$ACTION" == "add_proxy" ];then
      
      cat &lt;&lt; EOF_proxy &gt;&gt; "\$session_path/session.nsm"
NSM Proxy:nsm-proxy:\$clientID
EOF_proxy

      elif [ "\$ACTION" == "add_executable" ];then

      cat &lt;&lt; EOF_exec &gt;&gt; "\$session_path/session.nsm"
\$executable:\$executable:\$clientID
EOF_exec

      else
        echo "Unknown action type '\$ACTION' ! (You must call create_clientID first)"
      fi
      ;;
    *)
      echo "unknown session-manager '\$SESSION_MANAGER' error in set_client_properties"
      exit 1
      ;;
  esac

}

function init_session() {

  case "\$SESSION_MANAGER" in
    ray_control)
      echo "-------- Create new session named \$session_name"
      ray_control new_session "\$session_name"  || error

      session_path="\$(ray_control get_session_path)" || error
      ;;
    ray_xml)
      cat &lt;&lt; EOF &gt; "\$session_path/raysession.xml"
<RAYSESSION VERSION="0.8.3" name="\$session_name">
<Clients>
  <client icon="curve-connector" executable="ray-jackpatch" launched="1" id="patch" name="JACK Patch Memory"/>
EOF
      ;;
    nsm)
      echo -n &gt; "\$session_path/session.nsm"
    ;;
    *)
      echo "unknown session-manager '\$1' error in set_client_properties"
      exit 1
      ;;
  esac
}


function end_session() {

  case "\$SESSION_MANAGER" in
    ray_control)
      
      echo "-------- Save and close the session"
      ray_control close || error
      
      echo "-------- Copy raysession.xml to 'default/raysession.xml.backup'"
      filename="\$session_path/raysession.xml"
      mkdir -p "\$session_path/default"
      cp "\$filename" "\$session_path/default/raysession.xml.backup" || error

      if [ "\$startgui" == "gui" ]; then
        raysession --session="\$filename" || error
      else
        ray_control quit || error
      fi      
      ;;
    ray_xml)
      cat &lt;&lt; EOF &gt;&gt; "\$session_path/raysession.xml"
</Clients>
<RemovedClients/>
<Windows/>
</RAYSESSION>
EOF
      echo "-------- Copy raysession.xml to 'default/raysession.xml.backup'"
      filename="\$session_path/raysession.xml"
      mkdir -p "\$session_path/default"
      cp "\$filename" "\$session_path/default/raysession.xml.backup" || error
      ;;
    nsm)
    ;;
    *)
      echo "unknown session-manager '\$SESSION_MANAGER' error in set_client_properties"
      exit 1
      ;;
  esac
}

function gui_session() {

  case "\$SESSION_MANAGER" in
    ray_control)
      if [ "\$startgui" == "gui" ]
      then
        if [ "\$(which raysession)" != "" ]
        then
          echo "--Start gui"
          raysession --session="\$session_name" &amp;
        else
          echo -e "\e[1m\e[31mCommand not found 'raysession'\e[0m"
          exit 1
        fi
      else
        echo "--Stop the daemon"  
        ray_control close
        ray_control quit
      fi
      ;;
    ray_xml)
      raysession --session="\$session_name" &amp;
      ;;
    nsm)
      non-session-manager &amp;
    ;;
    *)
      echo "unknown session-manager '\$SESSION_MANAGER' error in set_client_properties"
      exit 1
      ;;
  esac

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

## copy filltemplate_dir (e.g. directory containing all default config files) to session_path
if [ ! -d "\$filltemplate_dir" ]
then
  echo -e "\e[1m\e[31mThe '\$filltemplate_dir' is not a directory !\e[0m"
  exit 1
fi

cp -r "\$filltemplate_dir/default" "\$session_path/" || error
echo "-------- default dir copied"

filename="\$session_path/\$session_name.patch.xml"
echo "-------- Install patch.xml to '\$filename'"
cp "\$filltemplate_dir/default/patch.xml" "\$filename" || error


if [ -d "\$filltemplate_dir/ray-scripts" ];then
  dir="\$session_path/ray-scripts"
  echo "-------- Copy ray-scripts to '\$dir'"
  cp -r "\$filltemplate_dir/ray-scripts" "\$dir" || error
fi

<xsl:for-each select="//template-snippet[@ref-id='session_sh']">
#[FROM] TEMPLATE SNIPPET Page id: <xsl:value-of select="../@id"/>
echo "-------- adding page '<xsl:value-of select="../@id"/>'"
<xsl:value-of select="."/>

#[/FROM] TEMPLATE SNIPPET Page id: <xsl:value-of select="../@id"/>
</xsl:for-each>

if [ "\$SESSION_MANAGER" == "nsm" ]; then
  note_file=ray_notes
else
  note_file=README
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

echo -e "\e[1m\e[32mRaySession '\$session_name' in '\$session_path' created successfully.\e[0m"

gui_session


</xsl:template>
</xsl:stylesheet>
