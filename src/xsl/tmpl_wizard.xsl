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

class SessionTemplate:
    
  def fillInTemplate(self, datamodelfile, rayZtemplatedir, outdir, fillonly=False, startgui=False, session_manager=None):
    
    if not os.path.isfile(rayZtemplatedir + os.sep + "info_wizard.xml"):
      raise Exception('%s is not a rayZtemplatedir !' % rayZtemplatedir)
    
    if not os.path.isdir(rayZtemplatedir):
      raise Exception('rayZtemplatedir "%s" must be a directory !' % rayZtemplatedir)
    
    sys.path.append(rayZtemplatedir)

    if not os.path.isfile(datamodelfile):
      raise Exception('datamodel "%s" must be a file !' % datamodelfile)

    if not os.path.isdir(outdir):
      raise Exception('outdir "%s" must be a directory !' % outdir)
    
    if os.path.isdir(rayZtemplatedir + os.sep + 'tmpl'):
      sys.path.append(rayZtemplatedir + os.sep + 'tmpl')
    
    srcpath = rayZtemplatedir + os.sep + 'default'
    if os.path.isdir(srcpath):
      destfilepath = outdir + os.sep + 'default'
      shutil.copytree(srcpath, destfilepath)
      print ("-- Copy default dir from rayZtemplatedir in temporary dir")
    else:
      print ('-- no default dir found in ' + rayZtemplatedir)

    srcpath = rayZtemplatedir + os.sep + 'local'
    if os.path.isdir(srcpath):
      destfilepath = outdir + os.sep + '.local'
      shutil.copytree(srcpath, destfilepath)
      print ("-- Copy local dir from rayZtemplatedir in temporary .local dir")
    else:
      print ('-- no local dir found in ' + rayZtemplatedir)

      
    srcpath = rayZtemplatedir + os.sep + 'ray-scripts'
    if os.path.isdir(srcpath):
      destfilepath = outdir + os.sep + 'ray-scripts'
      shutil.copytree(srcpath, destfilepath)
      print ("-- Copy ray-scripts dir from rayZtemplatedir in temporary dir")
    else:
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
    print ('---- Copying datamodel.json to %s' % destfilepath)

    print(json.dumps(data, indent=4, sort_keys=True))
    session_name = data['global.session_name']
    
    print ("-- Fill template in temporary dir")

    shutil.copy(datamodelfile, destfilepath)
    print ("---- %s copied" % destfilepath)

    <xsl:apply-templates select="//template" mode="build"/>

    <xsl:apply-templates select='template/fill-template[@type="patch_xml"][1]'/>

    <xsl:apply-templates select='template/fill-template[@type="create-session"][1]'/>

def usage():
  print ("Usage:")
  print ("<xsl:value-of select="@id"/>.py [options)")
  print ("   -h|--help                  : print this help text")
  print ("   -d                         : debug information")
  print ("   -j|--read-json-file  arg   : set the JSON file to read. It is used to fill template and contains wizard inputs. (default to ./datamodel.json)")
  print ("   -t|--rayZ-template-dir arg : set the rayZ template directory that contains the template related to this wizard. (default to ~/.local/share/raysession-templates/<xsl:value-of select="@id"/>")
  print ("   -f|--fill-only             : fill the template only (do not create the raysession")
  print ("   -s|--start-gui             : Once the raysession document has been created start the raysession GUI.")
  print ("   -m|--session-manager       : set the session-manager of the resulting document")
  print ("                                - ray_control : create a raysession document. You will need raysession software for the processing,")
  print ("                                - ray_xml     : create a raysession document. You wont need raysession for the document generation,")
  print ("                                - nsm         : create a nsm session. You wont need non-session-manager for the document generation,")

if __name__ == '__main__':
  datamodelfile = "./datamodel.json"
  rayZtemplatedir = '.'
  fillonly = False
  startgui = False
  session_manager= 'ray_control'
  import sys
  try:                                
    opts, args = getopt.getopt(sys.argv[1:], "ht:j:dfs:", ["help", "read-json-file=","rayZ-template-dir=","fill-only","start-gui","session-manager="])
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
    elif opt in ("-t", "--rayZ-template-dir"):
        rayZtemplatedir = arg
        print ("rayZ template dir is '%s'" % rayZtemplatedir)
    elif opt in ("-f", "--fill-only"):
        fillonly = True
    elif opt in ("-s", "--start-gui"):
        startgui = True
    elif opt in ("-m", "--session-manager"):
      session_manager=arg
      if session_manager not in ['ray_control', 'ray_xml', 'nsm']:  
        print ('--session-manager options : "ray_control|ray_xml|nsm"')
        sys.exit(2)
  
  tmpdir = tempfile.mkdtemp()
  
  if SessionTemplate().fillInTemplate(datamodelfile, rayZtemplatedir, tmpdir, fillonly=fillonly, startgui=startgui, session_manager=session_manager) == 0:          
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
      shutil.copy(rayZtemplatedir + os.sep + '<xsl:value-of select="@src"/>', destfilepath)
    
</xsl:template>

<xsl:template match="copy-tree" mode="build">
    
    section = "<xsl:value-of select="../../@section-name"/>"
    if section == '' or section in data['wizard.sectionnamelist']:
      destfilepath = outdir + os.sep + '<xsl:value-of select='@dest'/>'
      print ('---- Copy tree to %s' % destfilepath) 
      shutil.copytree(rayZtemplatedir + os.sep +  '<xsl:value-of select="@src"/>', destfilepath)
    
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

<xsl:template match="fill-template[@type='create-session']">
    if not fillonly:
      print ("---- Executing shell script %s " % (outdir + os.sep + '<xsl:value-of select="@dest"/>'))
      guioption = None
      if startgui:
        guioption = 'gui'
      else:
        guioption = 'nogui'
      raysession_create_command = [outdir + os.sep + '<xsl:value-of select='@dest'/>', session_name, outdir, session_manager, guioption]
      
      output = subprocess.check_call(raysession_create_command,stdout=sys.stdout)
    return True
</xsl:template>

<xsl:template match="fill-template[@type='patch_xml']">

    destfilepath = ''

    if session_manager == 'nsm':
      os.remove(outdir + os.sep + '<xsl:value-of select='@dest'/>')
      
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
      dest1 = outdir + os.sep + 'default' + os.sep + "patch.xml"
      dest2 = outdir + os.sep + '<xsl:value-of select='@dest'/>'
      if not os.path.samefile(dest1,dest2):
        destfilepath = dest1
        shutil.copy('<xsl:value-of select='@src'/>', destfilepath)
      
    print ("---- %s generated" % destfilepath)
</xsl:template>


</xsl:stylesheet>
