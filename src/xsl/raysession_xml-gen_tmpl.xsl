<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard"><![CDATA[<RAYSESSION VERSION="0.8.3" name="Playing in the name">
<Clients>]]>
  <![CDATA[<client icon="curve-connector" executable="ray-jackpatch" launched="1" id="patch" name="JACK Patch Memory"/>]]>
#set $clientCount = 0
#if 'alsa_in_devices' in $data
#for $device in $data['alsa_in_devices']
#set $clientCount = $clientCount + 1
#set $clientID = str($clientCount) + "_" + "alsa_in"
  <![CDATA[<client icon="alsa_in_x11" executable="alsa_in" name="capture $device" launched="1" id="$clientID" arguments="-j in_$device -d hw:$device" />]]>
#end for
#end if
#if 'alsa_out_devices' in $data
#for $device in $data['alsa_out_devices']
#set $clientCount = $clientCount + 1
#set $clientID = str($clientCount) + "_" + "alsa_out"
  <![CDATA[<client icon="alsa_out_x11" executable="alsa_out" name="playback $device" launched="1" id="$clientID" arguments="-j out_$device -d hw:$device" />]]>
#end for
#end if
<xsl:for-each select="//template-snippet[@ref-id='raysession_xml']">
<xsl:value-of select="."/>
</xsl:for-each>
<![CDATA[</Clients>
<RemovedClients/>
<Windows/>
</RAYSESSION>]]>
</xsl:template>
</xsl:stylesheet>
