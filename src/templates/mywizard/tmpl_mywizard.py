#!/usr/bin/env python

from lxml import etree
from io import StringIO
import shutil
import os, sys, stat
import json
import subprocess

class RaySessionTemplate:
  
  def translateData(datamodel):
    datamodel['listOfUsers'] = datamodel['global.users'].split(',')
  
  def fillInTemplate(self, datamodelfile, templatedir, outdir, finaldir):
    if not os.path.isdir(templatedir):
      raise Exception('templatedir "%s" must be a directory !' % templatedir)
      
    if not os.path.isfile(datamodelfile):
      raise Exception('datamodel "%s" must be a file !' % datamodelfile)

    if not os.path.isdir(outdir):
      raise Exception('outdir "%s" must be a directory !' % outdir)
          
    if os.path.isdir(finaldir):
      raise Exception('finaldir "%s" exists ! cannot overwrite ...' % finaldir)

    sys.path.append(templatedir)

    #from jack_connect_sh import jack_connect_sh
    from jack_connect_xml import jack_connect_xml
    from raysession_ray_control_sh import raysession_ray_control_sh

    print ("-- Creating directory structure ")
    os.makedirs(outdir + os.sep + 'etc' + os.sep + 'default',exist_ok=True)    
    os.makedirs(outdir + os.sep + 'templates' ,exist_ok=True)
    os.makedirs(outdir + os.sep + 'bin' ,exist_ok=True)
    
    print ("-- Copying templates files ")
    
    shutil.copytree(templatedir, outdir + os.sep + 'templates', dirs_exist_ok=True)
    
    print ("-- Reading datamodel ")
    
    with open(datamodelfile) as json_file:
      datamodel = json.load(json_file)
    
    print(json.dumps(datamodel, indent=4, sort_keys=True))
    raysession_name = datamodel['global.raysession_name']
    print ("-- Creating RaySession " + raysession_name)
    
    destfilepath = outdir + os.sep + 'etc' + os.sep + 'default' + os.sep + 'datamodel.json'
    shutil.move(datamodelfile, destfilepath)
    print ("... %s copied" % destfilepath)

    srcfilepath = templatedir + os.sep + 'templates' + os.sep + 'Jamulus'
    destfilepath = outdir + os.sep + 'bin' + os.sep + 'Jamulus'
    
    shutil.move(datamodelfile, destfilepath)
    print ("... %s copied" % destfilepath)


#    t = jack_connect_sh()
    t = jack_connect_xml()
    t.datamodel = datamodel
    destfilepath = outdir + os.sep + 'templates' + os.sep + 'patch.xml'
    f = open(destfilepath,"w+")
    content=str(t)
    doc = etree.XML(content.encode())
    f.write(content)
    f.close()
    os.chmod(destfilepath, stat.S_IREAD | stat.S_IWRITE | stat.S_IEXEC)
    print ("--- %s generated" % destfilepath)

    t = raysession_ray_control_sh()
    t.datamodel = datamodel
    destfilepath = outdir + os.sep + 'templates' + os.sep + 'raysession.sh'
    f = open(destfilepath,"w+") 
    content=str(t)
    f.write(content)
    f.close()
    os.chmod(destfilepath, stat.S_IREAD | stat.S_IWRITE | stat.S_IEXEC)
    print ("--- %s generated" % destfilepath)

    raysession_create_command = [outdir + os.sep + 'templates' + os.sep + 'raysession.sh', datamodel['global.raysession_name'], outdir]
    
    output = subprocess.run(raysession_create_command,shell=False,stdout=subprocess.PIPE)

    return output.returncode
