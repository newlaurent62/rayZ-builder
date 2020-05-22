<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">#!/bin/bash
#
# $1 : new_raysession_name
# $2 : copy the fill in config files to the new raysession name
#

LOCALTMPLPATH=/home/\$USER/.local/share/raysession-templates/$data['wizard.id']

function error() {
  echo -e "\e[1m\e[31mAn error occured. See log above.\e[0m"
  ray_control get_port &amp;&amp; ray_control quit
  yad --error --title "Raysession creation" --text="An error occured during the raysession creation ! (see logs for more details)"
  exit 1
}

if [ $# -ne 3 ]
then
  echo "Usage:"
  echo "  raysession.sh NEW_RAYSESSION_NAME TEMPLATE_DIR gui|nogui "
  exit 1
fi

raysession_name="\$1"
filltemplate_dir="\$2"
startgui="\$3"

if [ "\$RAY_SESSION_ROOT" == ""  ]
then
  error
else
  if [ ! -d "\$RAY_SESSION_ROOT" ]
  then
    mkdir -p "\$RAY_SESSION_ROOT"
  fi
fi

raysession_path="\$RAY_SESSION_ROOT/\$raysession_name"

echo "------ filltemplate_dir: \$filltemplate_dir"
echo "------ raysession_path: \$raysession_path"

mkdir -p "\$raysession_path" || error
echo "------ RaySession dir created"

## copy filltemplate_dir (e.g. directory containing all default config files) to raysession_path
if [ ! -d "\$filltemplate_dir" ]
then
  echo -e "\e[1m\e[31mThe '\$filltemplate_dir' is not a directory !\e[0m"
  exit 1
fi

cp -r "\$filltemplate_dir/default" "\$raysession_path/" || error
echo "------ default dir copied"

filename="\$raysession_path/\$raysession_name.patch.xml"
echo "------ Install patch.xml to '\$filename'"
cp "\$filltemplate_dir/default/patch.xml" "\$filename" || error

filename="\$raysession_path/raysession.xml"
echo "------ Install raysession.xml to '\$filename'"
cp "\$filltemplate_dir/default/raysession.xml.backup" "\$filename" || error

if [ -d "\$filltemplate_dir/ray-scripts" ];then
  dir="\$raysession_path/ray-scripts"
  echo "------ Copy ray-scripts to '\$dir'"
  cp -r "\$filltemplate_dir/ray-scripts" "\$dir" || error
fi

echo "CHECK_SERVER=1" > "\$dir/.env"
echo "CHECK_ADDITIONNAL_AUDIO_DEVICES=1" >> "\$dir/.env" 
echo "------ \$dir/.env generated"

#set $clientCount = 0

# client Count additions to synchronize with raysession_xml template

#if 'alsa_in_devices' in $data
#for $device in $data['alsa_in_devices']
#set $clientCount = $clientCount + 1
#end for
#end if

#if 'alsa_out_devices' in $data
#for $device in $data['alsa_out_devices']
#set $clientCount = $clientCount + 1
#end for
#end if

<xsl:for-each select="//template-snippet[@ref-id='raysession_sh']">
#[FROM] TEMPLATE SNIPPET Page id: <xsl:value-of select="../@id"/>

<xsl:value-of select="."/>

#[/FROM] TEMPLATE SNIPPET Page id: <xsl:value-of select="../@id"/>
</xsl:for-each>

if [ "\$startgui" == "gui" ]
then
  if [ "\$(which raysession)" != "" ]
  then
    raysession --session="\$raysession_name" &amp;
  fi
fi
</xsl:template>
</xsl:stylesheet>
