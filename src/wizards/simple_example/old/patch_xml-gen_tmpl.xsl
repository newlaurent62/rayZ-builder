<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard"><![CDATA[<RAY-JACKPATCH>
 <connection to="PulseAudio JACK Source:front-right" from="system:capture_2"/>
 <connection to="PulseAudio JACK Source:front-left" from="system:capture_1"/>
 <connection to="system:playback_1" from="PulseAudio JACK Sink:front-left"/>
 <connection to="system:playback_2" from="PulseAudio JACK Sink:front-right"/>]]>
<xsl:for-each select="//template-snippet[@ref-id='patch_xml']">
<xsl:value-of select="."/>
</xsl:for-each>
<![CDATA[</RAY-JACKPATCH>]]>
</xsl:template>
</xsl:stylesheet>
