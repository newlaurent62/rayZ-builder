<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard"><xsl:element name="wizard"><xsl:element name="info"><xsl:attribute name="id"><xsl:value-of select="@id"/></xsl:attribute><xsl:apply-templates select="info"/></xsl:element></xsl:element></xsl:template>

<xsl:template match="info">
<xsl:copy-of select="./*"/>
</xsl:template>
</xsl:stylesheet>
