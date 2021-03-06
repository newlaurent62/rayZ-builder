<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">#!/bin/bash
#!/bin/bash

########################################################################
#                                                                      #
#  Here you can edit the script runned                                 #
#  each time daemon order this session to be closed                    #
#  WARNING: You can be here in a switch situation,                     #
#           a session can be opened just after.                        #
#                                                                      #
#  You have access the following environment variables                 #
#  RAY_SESSION_PATH : Folder of the current session                    #
#  RAY_FUTURE_SESSION_PATH: Folder of the session that will be opened  #
#     just after current session close.                                #
#  RAY_SCRIPTS_DIR  : Folder containing this script                    #
#     ray-scripts folder can be directly in current session            #
#     or in a parent folder.                                           #
#  RAY_PARENT_SCRIPT_DIR : Folder containing the scripts that would    #
#     be runned if RAY_SCRIPTS_DIR would not exists                    #
#  RAY_SWITCHING_SESSION: 'true' or 'false'                            #
#     'true' if session is switching from another session              #
#     and probably some clients are still alive.                       #
#                                                                      #
#  To get any other session informations, refers to ray_control help   #
#     typing: ray_control --help                                       #
#                                                                      #
########################################################################


# script here some actions to run before closing the session.


# some clients may keep alive because
# they are needed by the session to open just after.
# if for some reasons you want all clients to stop
# set this variable true !
close_all_clients=false

USE_JACK_SETTINGS=false
RAY_HOSTNAME_SENSIBLE=false

if [ -f "\$RAY_SCRIPTS_DIR/.env" ]; then
  source "\$RAY_SCRIPTS_DIR/.env"
fi

export RAY_HOSTNAME_SENSIBLE

close_all_if_needed=''

if \$USE_JACK_SETTINGS; then

  if [[ "\$RAY_FUTURE_SCRIPTS_DIR" != "\$RAY_SCRIPTS_DIR" ]] &amp;&amp;\
          ! [ -f "\$RAY_FUTURE_SCRIPTS_DIR/.jack_config_script" ];then
      close_all_if_needed=close_all
  fi
fi

<xsl:apply-templates select='//template-snippet[@ref-id="ray_script_close_sh"]' mode="copy-no-namespaces"/>

ray_control run_step \$close_all_if_needed

if \$USE_JACK_SETTINGS; then
  if [ -n "\$close_all_if_needed" ];then
      ray-jack_config_script putback &amp;&amp; ray_control hide_script_info
  fi
fi

# script here some actions to run once the session is closed

</xsl:template>

<xsl:template match="*" mode="copy-no-namespaces"><xsl:element name="{local-name()}"><xsl:copy-of select="@*"/><xsl:apply-templates select="node()" mode="copy-no-namespaces"/></xsl:element></xsl:template>

<xsl:template match="comment()| processing-instruction()" mode="copy-no-namespaces"><xsl:copy/></xsl:template>

</xsl:stylesheet>
