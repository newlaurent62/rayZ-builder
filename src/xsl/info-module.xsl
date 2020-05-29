<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="no" />
<xsl:template match="/wizard">
class WizardInfo:

  def __init__(self):
    self._id = '<xsl:value-of select='info/@id'/>'
    self._title = '<xsl:value-of select='info/title'/>'
    self._version = '<xsl:value-of select='info/version'/>'
    self._keywords = '<xsl:value-of select='info/keywords'/>'
    self._keywordslist = self._keywords.split(',')

</xsl:template>
</xsl:stylesheet>
