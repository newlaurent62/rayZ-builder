<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">
  <![CDATA[<session>]]>
    &lt;info&gt;
      &lt;title&gt;<xsl:value-of select="info/title"/>&lt;/title&gt;
      &lt;category&gt;<xsl:value-of select="info/category"/>&lt;/category&gt;
      &lt;keywords&gt;<xsl:value-of select="info/keywords"/>&lt;/keywords&gt;
      &lt;version&gt;v<xsl:value-of select="info/version"/>&lt;/version&gt;
      &lt;description&gt;<xsl:value-of select="info/description"/>&lt;/description&gt;
      &lt;author&gt;<xsl:value-of select="info/author"/>&lt;/author&gt;
      &lt;email&gt;<xsl:value-of select="info/email"/>&lt;/email&gt;
    &lt;/info&gt;
    <xsl:for-each select="//page">
      <xsl:if test=".//template-snippet[@ref-id='session_sh']">
      <![CDATA[<page><section-name>]]><xsl:value-of select="@section-name"/><![CDATA[</section-name>]]>
        <xsl:for-each select=".//template-snippet[@ref-id='session_sh']">
          <xsl:value-of select="."/>
        </xsl:for-each>
      <![CDATA[</page>]]>
      </xsl:if>
    </xsl:for-each>
  <![CDATA[</session>]]>
</xsl:template>

<xsl:template match="*" mode="copy-no-namespaces"><xsl:element name="{local-name()}"><xsl:copy-of select="@*"/><xsl:apply-templates select="node()" mode="copy-no-namespaces"/></xsl:element></xsl:template>

<xsl:template match="comment()| processing-instruction()" mode="copy-no-namespaces"><xsl:copy/></xsl:template>

</xsl:stylesheet>
