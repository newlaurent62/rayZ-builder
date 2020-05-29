<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="no" />
<xsl:template match="/RAY-JACKPATCH">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="text()">
<xsl:value-of select="."/>
</xsl:template>

<xsl:template match="connection">
<xsl:choose>
<xsl:when test="string-length(@from) &lt; 42">
<xsl:value-of select="substring(concat(@from, string-join((for $i in 1 to 42 return ' '),'')),1,42)"/> |&gt; <xsl:value-of select="@to"/>
</xsl:when>
<xsl:otherwise>
<xsl:value-of select="@from"/> |&gt; <xsl:value-of select="@to"/>
</xsl:otherwise>
</xsl:choose>
</xsl:template>

</xsl:stylesheet>
