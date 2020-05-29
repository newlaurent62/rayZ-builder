<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" omit-xml-declaration="yes" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">
  <xsl:element name="wizard">
    <xsl:element name="info">
      <xsl:attribute name="id"><xsl:value-of select="@id"/></xsl:attribute>
      <xsl:apply-templates select="info" mode="copy-no-namespaces"/>
    </xsl:element>
  </xsl:element>
</xsl:template>

<xsl:template match="info" mode="copy-no-namespaces">
  <xsl:apply-templates mode="copy-no-namespaces"/>
</xsl:template>

<xsl:template match="*" mode="copy-no-namespaces">
    <xsl:element name="{local-name()}">
        <xsl:copy-of select="@*"/>
        <xsl:apply-templates select="node()" mode="copy-no-namespaces"/>
    </xsl:element>
</xsl:template>

<xsl:template match="comment()| processing-instruction()" mode="copy-no-namespaces">
    <xsl:copy/>
</xsl:template>

</xsl:stylesheet>
