<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">#!/usr/bin/env python

from lxml import etree
from io import StringIO
import shutil
import os, sys, stat
import json
import subprocess
import getopt
import tempfile
import lxml

# Project modules
from rayZ_i18n import *

class SessionTemplate:
    
  def fillInTemplate(self, datamodelfile, rayZtemplatedir, outdir, fillonly=False, startgui=False, session_manager=None, conffile=None, debug=None):
    print ('[==== fillInTemplate:')
    if not os.path.isfile(rayZtemplatedir + os.sep + "info_wizard.xml"):
      raise Exception(tr('%s is not a rayZtemplatedir !') % rayZtemplatedir)
    
    if not os.path.isdir(rayZtemplatedir):
      raise Exception(tr('rayZtemplatedir "%s" must be a directory !') % rayZtemplatedir)
    
    sys.path.append(rayZtemplatedir)

    if conffile and not os.path.isfile(conffile):
      raise Exception(tr('conf file "%s" must be a file !') % conffile)

    if not os.path.isfile(datamodelfile):
      raise Exception(tr('datamodel "%s" must be a file !') % datamodelfile)

    if not os.path.isdir(outdir):
      raise Exception(tr('outdir "%s" must be a directory !') % outdir)
        
    srcpath = rayZtemplatedir + os.sep + 'default'
    if os.path.isdir(srcpath):
      destfilepath = outdir + os.sep + 'default'
      shutil.copytree(srcpath, destfilepath)
      if debug:
        print ("-- Copy default dir from rayZtemplatedir in temporary dir")
    else:
      if debug:
        print ('-- no default dir found in ' + rayZtemplatedir)

    srcpath = rayZtemplatedir + os.sep + 'local'
    if os.path.isdir(srcpath):
      destfilepath = outdir + os.sep + '.local'
      shutil.copytree(srcpath, destfilepath)
      if debug:
        print ("-- Copy local dir from rayZtemplatedir in temporary .local dir")
    else:
      if debug:
        print ('-- no local dir found in ' + rayZtemplatedir)

      
    srcpath = rayZtemplatedir + os.sep + 'ray-scripts'
    if os.path.isdir(srcpath):
      destfilepath = outdir + os.sep + 'ray-scripts'
      shutil.copytree(srcpath, destfilepath)
      if debug:
        print ("-- Copy ray-scripts dir from rayZtemplatedir in temporary dir")
    else:
      if debug:
        print ('-- no ray-scripts dir found in ' + rayZtemplatedir)
      
    <xsl:for-each select='//fill-template'>
    from <xsl:value-of select='@id'/> import <xsl:value-of select='@id'/>
    </xsl:for-each>
    from nsm_patch import nsm_patch

    print ("-- Reading datamodel %s" % datamodelfile)

    with open(datamodelfile) as json_file:
      data = json.load(json_file)

    destfilepath = outdir + os.sep + 'default' + os.sep + 'datamodel.json'
    os.makedirs(os.path.dirname(destfilepath),exist_ok=True)    
    if debug:
      print ('---- Copying datamodel.json to %s' % destfilepath)

    if debug:
      print(json.dumps(data, indent=4, sort_keys=True))
    session_name = data['global.session_name']
    
    if debug:
      print ("-- Fill template in temporary dir")

    shutil.copy(datamodelfile, destfilepath)
    if debug:
      print ("---- %s copied" % destfilepath)

    if conffile:
      destfilepath = outdir + os.sep + 'default' + os.sep + conffile
      os.makedirs(os.path.dirname(destfilepath),exist_ok=True)    
      shutil.copy(conffile, destfilepath)
      if debug:
        print ("---- %s copied" % destfilepath)

    <xsl:apply-templates select="//template" mode="build"/>

    <xsl:apply-templates select='template/fill-template[@type="patch_xml"][1]'/>

    <xsl:apply-templates select='template/fill-template[@type="create-session"][1]'/>

def usage():
  print (tr("Usage:"))
  print (tr("tmpl_wizard.py [options)"))
  print (tr("   -h|--help                  : print this help text"))
  print (tr("   -d                         : debug information"))
  print (tr("   -j|--read-json-file  arg   : set the JSON file to read. It is used to fill template and contains wizard inputs. (default to %s)") % "./datamodel.json")
  print (tr("   -t|--rayZ-template-dir arg : set the rayZ template directory that contains the template related to this wizard. (default to %s)") % "~/.local/share/raysession-templates/<xsl:value-of select="@id"/>")
  print (tr("   -f|--fill-only             : fill the template only (do not create the raysession"))
  print (tr("   -s|--start-gui             : Once the session has been created start the session manager GUI."))
  print (tr("   -m|--session-manager       : set the session-manager of the resulting document"))
  print (tr("                                - ray_control : create a ray session document. You will need RaySession software for the processing,"))
  print (tr("                                - nsm         : create a nsm session. You wont need non-session-manager for the document generation,"))

if __name__ == '__main__':
  datamodelfile = "./datamodel.json"
  rayZtemplatedir = '.'
  fillonly = False
  startgui = False
  _debug = False
  session_manager= 'ray_control'
  import sys
  try:                                
    opts, args = getopt.getopt(sys.argv[1:], "hj:dt:fsm:", ["help", "read-json-file=","debug", "rayZ-template-dir=","fill-only","start-gui","session-manager="])
    print ("optlist: ")
    print(opts)
  except getopt.GetoptError:          
    usage()                         
    sys.exit(2)                     
  for opt, arg in opts:
    if opt in ("-h", "--help"):
        usage()                     
        sys.exit()                  
    elif opt in ('-d', "--debug"):
        _debug = True               
    elif opt in ("-j", "--read-json-file"):
        datamodelfile = arg
        print (tr("will write a json file '%s' when finishing the wizard steps.") % datamodelfile)
    elif opt in ("-t", "--rayZ-template-dir"):
        rayZtemplatedir = arg
        print (tr("rayZ template dir is '%s'") % rayZtemplatedir)
    elif opt in ("-f", "--fill-only"):
        fillonly = True
    elif opt in ("-s", "--start-gui"):
        startgui = True
    elif opt in ("-m", "--session-manager"):
      session_manager=arg
      if session_manager not in ['ray_control', 'nsm']:  
        print (tr('--session-manager options : "ray_control|nsm"'))
        sys.exit(2)
  
  tmpdir = tempfile.mkdtemp()
  
  if SessionTemplate().fillInTemplate(datamodelfile, rayZtemplatedir, tmpdir, fillonly=fillonly, startgui=startgui, session_manager=session_manager, debug=_debug) == 0:          
    print(tr('The session has been successfully created.'))
  
</xsl:template>

<xsl:template match="template" mode="build">
  <xsl:apply-templates mode="build"/>
</xsl:template>

<xsl:template match="copy-file" mode="build">

  
    <xsl:choose>
      <xsl:when test="ancestor::page/@section-name">
    section = "<xsl:value-of select="../../@section-name"/>"
      </xsl:when>
      <xsl:otherwise>
    section = None
      </xsl:otherwise>
    </xsl:choose>
    if not section or section in data['wizard.sectionnamelist']:
      destfilepath = outdir + os.sep + '<xsl:value-of select='@dest'/>'
      os.makedirs(os.path.dirname(destfilepath),exist_ok=True)    
      if debug:
        print ('---- Copy file to %s' % destfilepath)
      shutil.copy(rayZtemplatedir + os.sep + '<xsl:value-of select="@src"/>', destfilepath)
    
</xsl:template>

<xsl:template match="copy-tree" mode="build">
    
    <xsl:choose>
      <xsl:when test="ancestor::page/@section-name">
    section = "<xsl:value-of select="../../@section-name"/>"
      </xsl:when>
      <xsl:otherwise>
    section = None
      </xsl:otherwise>
    </xsl:choose>
    if not section or section in data['wizard.sectionnamelist']:
      destfilepath = outdir + os.sep + '<xsl:value-of select='@dest'/>'
      if debug:
        print ('---- Copy tree to %s' % destfilepath) 
      shutil.copytree(rayZtemplatedir + os.sep +  '<xsl:value-of select="@src"/>', destfilepath)
    
</xsl:template>

<xsl:template match="fill-template[@type != 'create-session' and @type != 'patch_xml']" mode="build">
    <xsl:choose>
      <xsl:when test="ancestor::page/@section-name">
    section = "<xsl:value-of select="../../@section-name"/>"
      </xsl:when>
      <xsl:otherwise>
    section = None
      </xsl:otherwise>
    </xsl:choose>
    if not section or section in data['wizard.sectionnamelist']:
      t = <xsl:value-of select='@id'/>()
      t.data = data
      destfilepath = outdir + os.sep + '<xsl:value-of select='@dest'/>'
      os.makedirs(os.path.dirname(destfilepath),exist_ok=True)    
      
      f = open(destfilepath,"w+")
      content=str(t)
      f.write(content)
      f.close()
      
      <!-- FILE SYNTAX CHECK -->
      <xsl:choose>
      <xsl:when test="ends-with(@dest,'.xml')">
      if debug:
        print ("---- %s : checking xml syntax " % destfilepath)
      try:
        doc = etree.XML(content.encode())
      except lxml.etree.XMLSyntaxError as e:
        raise e
      </xsl:when>
      <xsl:when test="ends-with(@dest,'.sh')">
      os.chmod(destfilepath, stat.S_IREAD | stat.S_IWRITE | stat.S_IEXEC)
      if debug:
        print ("---- %s checking shell script syntax" % destfilepath)
      shellcheck_create_command = ['bash', '-n', destfilepath]
      output = subprocess.check_call(shellcheck_create_command,stdout=sys.stdout)
      </xsl:when>
      </xsl:choose>    
      if debug:
        print ("---- %s generated" % destfilepath)
</xsl:template>


<xsl:template match="fill-template[@type='create-session']">
    t = session_sh()
    t.data = data
    destfilepath = outdir + os.sep + '<xsl:value-of select="@dest"/>'
    os.makedirs(os.path.dirname(destfilepath),exist_ok=True)
    
    f = open(destfilepath,"w+")
    content=str(t)
    f.write(content)
    f.close()

    os.chmod(destfilepath, stat.S_IREAD | stat.S_IWRITE | stat.S_IEXEC)
    if debug:
      print ("---- %s checking shell script syntax" % destfilepath)
    shellcheck_create_command = ['bash', '-n', destfilepath]
    output = subprocess.check_call(shellcheck_create_command,stdout=sys.stdout)

    if not fillonly:      
      if debug:
        print ("---- Executing shell script %s " % (outdir + os.sep + '<xsl:value-of select="@dest"/>'))
      guioption = None
      if startgui:
        guioption = 'gui'
      else:
        guioption = 'nogui'
      if debug:
        debugoption = 'debug'
      else:
        debugoption = 'nodebug'
        
      raysession_create_command = [outdir + os.sep + '<xsl:value-of select='@dest'/>', session_name, outdir, rayZtemplatedir, session_manager, guioption, debugoption]
      
      output = subprocess.check_call(raysession_create_command,stdout=sys.stdout)
      
    print (']==== fillInTemplate:')
    
    return True
</xsl:template>

<xsl:template match="fill-template[@type='patch_xml']">

    destfilepath = ''

    if session_manager == 'nsm':      
      t = nsm_patch()
      t.data = data
      destfilepath = outdir + os.sep + 'default' + os.sep + "nsm_patch.jackpatch"
      os.makedirs(os.path.dirname(destfilepath),exist_ok=True)    
      
      f = open(destfilepath,"w+")
      content=str(t)
      result = ''
      for line in content.split('\n'):
        if line.strip() != '':
          _list = line.split('|>')
          if len(_list) == 2:
            result += _list[0].strip().ljust(42) + ' |> ' + _list[1].strip() + "\n"      
      f.write(result)
      f.close()
    else:
      t = patch_xml()
      t.data = data
      destfilepath = outdir + os.sep + 'default' + os.sep + "patch.xml"
      os.makedirs(os.path.dirname(destfilepath),exist_ok=True)
      
      f = open(destfilepath,"w+")
      
      f = open(destfilepath,"w+")
      content=str(t)
      f.write(content)
      f.close()

      if debug:
        print ("---- %s : checking xml syntax " % destfilepath)
      try:
        doc = etree.XML(content.encode())
      except lxml.etree.XMLSyntaxError as e:
        raise e
      
      
      dest1 = outdir + os.sep + 'default' + os.sep + "patch.xml"
      dest2 = outdir + os.sep + '<xsl:value-of select='@dest'/>'
      if not os.path.samefile(dest1,dest2):
        shutil.copy(dest1, dest2)
      
    if debug:
      print ("---- %s generated" % destfilepath)
</xsl:template>

</xsl:stylesheet>
