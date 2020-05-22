<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
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

class RaySessionTemplate:
    
  def fillInTemplate(self, datamodelfile, templatedir, outdir, fillonly=False, startgui=False):
    
    if not os.path.isdir(templatedir):
      raise Exception('templatedir "%s" must be a directory !' % templatedir)
    
    sys.path.append(templatedir)

    if not os.path.isfile(datamodelfile):
      raise Exception('datamodel "%s" must be a file !' % datamodelfile)

    if not os.path.isdir(outdir):
      raise Exception('outdir "%s" must be a directory !' % outdir)
    
    if os.path.isdir(templatedir + os.sep + 'tmpl'):
      sys.path.append(templatedir + os.sep + 'tmpl')
        
    <xsl:for-each select='//fill-template'>
    from <xsl:value-of select='@id'/> import <xsl:value-of select='@id'/>
    </xsl:for-each>

    print ("-- Reading datamodel %s" % datamodelfile)

    with open(datamodelfile) as json_file:
      data = json.load(json_file)

    destfilepath = outdir + os.sep + 'etc' + os.sep + 'default' + os.sep + 'datamodel.json'
    os.makedirs(os.path.dirname(destfilepath),exist_ok=True)    
    print ('---- Copying datamodel.json to %s' % destfilepath)

    print(json.dumps(data, indent=4, sort_keys=True))
    raysession_name = data['global.raysession_name']
    
    print ("-- Fill template in temporary dir")

    shutil.copy(datamodelfile, destfilepath)
    print ("---- %s copied" % destfilepath)

    <xsl:apply-templates select="//template" mode="build"/>

    <xsl:apply-templates select='template/fill-template[@type="create-raysession"][1]'/>

def usage():
  print ("Usage:")
  print ("<xsl:value-of select="@id"/>.py [options)")
  print ("   -h|--help                : print this help text")
  print ("   -d                       : debug information")
  print ("   -j|--read-json-file  arg : set the JSON file to read. It is used to fill template and contains wizard inputs. (default to ./datamodel.json)")
  print ("   -t|--template-dir    arg : set the template directory that contains the template related to this wizard. (default to ~/.local/share/raysession-templates/<xsl:value-of select="@id"/>")
  print ("   -f|--fill-only           : fill the template only (do not create the raysession")
  print ("   -s|--start-gui           : Once the raysession document has been created start the raysession GUI.")
    
if __name__ == '__main__':
  datamodelfile = "./datamodel.json"
  templatedir = 'xxx-TEMPLATE_DIR-xxx'
  fillonly = False
  startgui = False
  import sys
  try:                                
    opts, args = getopt.getopt(sys.argv[1:], "hj:t:dfs", ["help", "read-json-file=","template-dir=","fill-only","start-gui"])
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
        global _debug               
        _debug = 1               
    elif opt in ("-j", "--read-json-file"):
        datamodelfile = arg
        print ("will write a json file '%s' when finishing the wizard steps." % datamodelfile)
    elif opt in ("-t", "--template-dir"):
        templatedir = arg
        print ("Template dir is '%s'" % templatedir)
    elif opt in ("-f", "--fill-only"):
        fillonly = True
    elif opt in ("-s", "--start-gui"):
        startgui = True

  tmpdir = tempfile.mkdtemp()
  
  if RaySessionTemplate().fillInTemplate(datamodelfile, templatedir, tmpdir, fillonly=fillonly, startgui=startgui) == 0:          
    print('The RaySession has been successfully created.')
  
</xsl:template>

<xsl:template match="template" mode="build">
  <xsl:apply-templates mode="build"/>
</xsl:template>

<xsl:template match="copy-file" mode="build">

  
    section = "<xsl:value-of select="../../@section-name"/>"
    if section == '' or section in data['wizard.sectionnamelist']:
      destfilepath = outdir + os.sep + '<xsl:value-of select='@dest'/>'
      os.makedirs(os.path.dirname(destfilepath),exist_ok=True)    
      print ('---- Copy file to %s' % destfilepath)
      shutil.copy(templatedir + os.sep + '<xsl:value-of select="@src"/>', destfilepath)x
    
</xsl:template>

<xsl:template match="copy-tree" mode="build">
    
    section = "<xsl:value-of select="../../@section-name"/>"
    if section == '' or section in data['wizard.sectionnamelist']:
      destfilepath = outdir + os.sep + '<xsl:value-of select='@dest'/>'
      print ('---- Copy tree to %s' % destfilepath) 
      shutil.copytree(templatedir + os.sep +  '<xsl:value-of select="@src"/>', destfilepath)
    
</xsl:template>
<xsl:template match="fill-template" mode="build">
    section = "<xsl:value-of select="../../@section-name"/>"
    if section == '' or section in data['wizard.sectionnamelist']:
      t = <xsl:value-of select='@id'/>()
      t.data = data
      destfilepath = outdir + os.sep + '<xsl:value-of select='@dest'/>'
      os.makedirs(os.path.dirname(destfilepath),exist_ok=True)    
      
      f = open(destfilepath,"w+")
      content=str(t)
      f.write(content)
      f.close()
      os.chmod(destfilepath, stat.S_IREAD | stat.S_IWRITE | stat.S_IEXEC)
      
      <!-- FILE SYNTAX CHECK -->
      <xsl:choose>
      <xsl:when test="ends-with(@dest,'.xml')">
      print ("---- %s : checking xml syntax " % destfilepath)
      try:
        doc = etree.XML(content.encode())
      except lxml.etree.XMLSyntaxError as e:
        raise e
      </xsl:when>
      <xsl:when test="ends-with(@dest,'.sh')">
      print ("---- %s checking shell script syntax" % destfilepath)
      shellcheck_create_command = ['bash', '-n', destfilepath]
      output = subprocess.check_call(shellcheck_create_command,stdout=sys.stdout)
      </xsl:when>
      </xsl:choose>    
      print ("---- %s generated" % destfilepath)
</xsl:template>

<xsl:template match="fill-template[@type='create-raysession']">
    if not fillonly:
      print ("---- Executing shell script %s " % (outdir + os.sep + '<xsl:value-of select="@dest"/>'))
      guioption = None
      if startgui:
        guioption = 'gui'
      else:
        guioption = 'nogui'
      raysession_create_command = [outdir + os.sep + '<xsl:value-of select='@dest'/>', raysession_name, outdir, guioption]
      
      output = subprocess.check_call(raysession_create_command,stdout=sys.stdout)
    return True
</xsl:template>

</xsl:stylesheet>
