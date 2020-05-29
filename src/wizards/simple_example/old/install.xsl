<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="wizard">#!/bin/bash -x

function install_package_from_executable() {
EXECUTABLE="$1"
VERSION="$2"
if [ "EXECUTABLE" != "" ]
then
  RESULT=$(apt-file search --regexp "bin/$EXECUTABLE$")
  if [ $? -ne 0 ]
  then
    echo -e "\e[1m\e[31m-- Could not find the executable '$EXECUTABLE' in the current repositories ...\e[0m"
    exit 1
  fi
  DEB_PKG=$(echo "$RESULT" | cut -d":" -f1)
  if [ "$DEB_PKG" != "" ]
  then
    echo "-- Installing '$DEB_PKG'"
    sudo apt install "$DEB_PKG"
    if [ $? -ne 0 ]
    then
      echo -e "\e[1m\e[31m-- An error occured during the '$DEB_PKG' installation process ...\e[0m"
      exit 1
    fi
  fi
  echo "-- '$EXECUTABLE' found in '$DEB_PKG'"
  REPORT="$REPORT\e[1m\e[32m-- $EXECUTABLE has been found in package '$DEB_PKG' [ $(if [ "$VERSION" == "" ]; then echo "No version required"; else echo "Version required: $VERSION"; fi) / Installed $(apt-cache show $DEB_PKG | grep Version) ]\e[0m\n"
fi
}

if [ "$(which apt-file)" == "" ]
then
  echo -e "\e[1m\e[31mError: please install apt-file\e[0m"
  exit 1
fi

echo "-- Updating repositories"
sudo apt update
REPORT=""
<xsl:apply-templates select='//requires'/>
REPORT="\e[32m$REPORT\e[0m"

echo 
echo -e "\e[1mReport:\e[0m"
echo
echo -e "$REPORT"

</xsl:template>

<xsl:template match='requires'>
install_package_from_executable "<xsl:value-of select='@executable'/>" "<xsl:value-of select="@version"/>"
</xsl:template>

</xsl:stylesheet>
