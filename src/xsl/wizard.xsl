<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="wizard">#!/usr/bin/env python

# libs
from PyQt5 import QtCore
from PyQt5 import QtGui
from PyQt5.QtCore import pyqtProperty
from PyQt5 import QtCore, QtWidgets
import platform    
import subprocess
import configparser
import os
import io
import tempfile
import collections
import json
import re
import shutil

# Project files
from ui_userslistedit import UsersListEdit
from ui_checklineedit import CheckLineEdit
from ui_pathlineedit import PathLineEdit

serverQregexp = QtCore.QRegularExpression("^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|((([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9])))$")

pathQregexp = QtCore.QRegularExpression("^(\\/(([ A-Za-z0-9-_+]|\\.)+\\/)*([A-Za-z0-9_-]|\\.)+)$")
directoryQregexp = QtCore.QRegularExpression("^(\\/(([ A-Za-z0-9-_+]|\\.)+\\/)*([A-Za-z0-9_-]|\\.)+)$")
filenameQregexp = QtCore.QRegularExpression("^([A-Za-z0-9_-]|\\.)+$")
sessionNameQregexp = QtCore.QRegularExpression("^((?!--)([ _A-Za-z0-9-]|\\.))+$")
nameAndPasswordQregexp = QtCore.QRegularExpression("^((?!--)([_A-Za-z0-9-]|\\.))+$")
usersQregexp = QtCore.QRegularExpression("^((?!--)([_A-Za-z0-9-]|\\.)+)(,((?!--)([_A-Za-z0-9-]|\\.)+))*$")

inputsregexp = "((([a-zA-Z]\w*):)?([0-9]+))(,((([a-zA-Z]\w*):)?([0-9]+)))*->(LR|L|R|)\s*"
inputsre = re.compile(inputsregexp)
outputsregexp = "(LR|L|R)->(([a-zA-Z]\w*):)?([0-9]+)(,(([a-zA-Z]\w*):)?([0-9]+))*\s*"
outputsre = re.compile(outputsregexp)

class DataModel:
    
  config = None
  
  configfilename = '<xsl:value-of select='@id'/>.conf'
  
  raysession_root = os.environ.get('RAY_SESSION_ROOT', '~/"Ray Sessions"')
  
  raysession_path = None
  
  registeredkey = {}

  data = {}
  
  def __init__(self, wizard):
    self.wizard = wizard
  
  def readConf(self):
    config = configparser.ConfigParser()
    if os.path.isfile(self.configfilename):      
      print ('Reading ' + self.configfilename)
      config.read(self.configfilename)
    
    self.config = config
   
  def registerkey(self, sectionName, key):
    if not (sectionName in self.registeredkey):
      self.registeredkey[sectionName] = set([])
    self.registeredkey[sectionName].add(key)
      
  def removeRegisteredKey(self, section, property_hided):
    r = []
    if section in self.registeredkey:
      for key in self.registeredkey[section]:
        if key.startswith(property_hided):
          r.append(key)
          
    for i in r:
      self.registeredkey[section].remove(i)
      
  def initFieldsOfSection(self,page):
    sectionname = page.sectionName
    if sectionname != None and sectionname in self.config.sections():
      print ('Loading [' + sectionname + '] values ...')
      for key in self.config[sectionname]:
        if not (key in self.config.defaults()):
          field_name = sectionname + '.' + key
          if field_name in page.field_names:
            try:
              value = self.config[sectionname][key]
              if key.startswith('bool'):
                page.setField(sectionname+ '.' + key, value == 'True')
              else:
                page.setField(sectionname+ '.' + key, value)
              print ('--' + sectionname + '.' + key + ':' + value)
            except KeyError:
              print ("--KeyError: loading value for %s.%s" % sectionname, key)
              self.config[sectionname][key] = self.field(sectionname+ '.' + key)
    else:
      page.defaults()

  def updateConf(self,page):
    sectionname = page.sectionName
    if sectionname != None:
      self.config[sectionname] = {}
      print ('Updating [' + sectionname + '] values in memory ...')
      for key in page.field_names:
        if key.startswith(sectionname):
          ckey = key[(len(sectionname)+1):]
          value = page.field(key)
          print ('--' + ckey  + ':' + str(value))
          self.config[sectionname][ckey] = str(value)
      

  def alsa_in_devices(self,ins):
    devices=[]
    for m in inputsre.finditer(ins):
      for i in range(len (m.groups())+1):
        match = m.group(i)
        if match != None:             
          if len(match) > 0 and not (':' in match) and not (',' in match) and not ('->' in match) and not match.isdigit() and not (match in ['L','R','LR']):
            device = match
            if not (device in devices):
              devices.append(device)
    return devices
  
  def alsa_out_devices(self, outs):
    devices=[]
    for m in outputsre.finditer(outs):
      for i in range(len (m.groups())+1):
        match = m.group(i)
        if match != None:             
          if len(match) > 0 and not (':' in match) and not (',' in match) and not ('->' in match) and not match.isdigit() and not (match in ['L','R','LR']):
            device = match
            if not (device in devices):
              devices.append(device)

    return devices

  def inputs(self,inputtype,content):
    result=[]
    devices=[]
    for m in inputsre.finditer(content):
      device = 'system'
      temp=[]
      #print(m.groups())
      for i in range(len (m.groups())+1):
        match = m.group(i)
        if match != None:             
          if match in [inputtype,'LR']:
            result.extend(temp)
            temp = []
          elif match != inputtype and match in ['L', 'R', 'LR']:
            temp = []            
          elif len(match) > 0 and not (':' in match) and not (',' in match) and match.isdigit():
            if device != 'system':
              jack_input = 'in_' + device + ':capture_' + match
            else:
              jack_input = device + ':capture_' + match            
            if not (jack_input in result) and not (jack_input in temp):
              temp.append(jack_input)
          elif len(match) > 0 and not (':' in match) and not (',' in match) and not ('->' in match):
            device = match
            if not (device in devices):
              devices.append(device)
              
    return result

  def outputs(self,inputtype,content):
    result=[]
    for m in outputsre.finditer(content):
      currenttype = None
      device = 'system'
      #print(m.groups())    
      for i in range(len (m.groups())+1):
        match = m.group(i)
        if match != None:
          if match in ['L', 'R', 'LR']:
            currenttype = match
          elif len(match) > 0 and not (':' in match) and not (',' in match) and match.isdigit():
            if device != 'system':
              jack_output = 'out_' + device + ':playback_' + match
            else:
              jack_output = device + ':playback_' + match
            if currenttype in [inputtype,'LR'] and not (jack_output in result):
              result.append(jack_output)
          elif len(match) > 0 and not (':' in match) and not (',' in match) and not ('->' in match):
            device = match
    return result

  def leftInputs(self, content):
    return self.inputs('L', content)

  def rightInputs(self, content):
    return self.inputs('R', content)
    
  def leftOutputs(self, content):
    return self.outputs('L', content)
  
  def rightOutputs(self, content):
    return self.outputs('R', content)
  
  def field(self, name):
    return self.wizard.field(name)
  
  def setField(self, name, value):
    return self.wizard.setField(name, value)


  def sessionNameAlreadyUsed(self):    
    self.raysession_path = self.raysession_root + os.sep + self.field('<xsl:value-of select='//field[@id = "raysession_name"]/../@section-name'/>.raysession_name')
    if os.path.isdir(self.raysession_path):
      print('Directory "%s" already exist ! Choose another name or delete it first.' % self.raysession_path ) 
      return True
    else:
      print('Directory "%s" does not exist.' % self.raysession_path ) 
      return False

  def cleanConf(self):
    sections=[<xsl:for-each select='//page/@section-name'><xsl:if test='position() != 1'>,</xsl:if>'<xsl:value-of select='.'/>'</xsl:for-each>]
    
    new_config = configparser.ConfigParser({}, collections.OrderedDict)
    for section in sections:
      new_config[section]={}
      for ckey in self.config[section]:
        fieldkey = section + '.' + ckey
        if (fieldkey  in self.wizard.allFieldNames() or (section in self.registeredkey and ckey in self.registeredkey[section])) and not ('-hide' in ckey):
          if self.config[section][ckey] != None and self.config[section][ckey] != '':
            new_config[section][ckey] = self.config[section][ckey]
      new_config._sections[section] = collections.OrderedDict(sorted(new_config._sections[section].items(), key=lambda t: t[0]))
    
    return new_config

  def cleanConfAsString(self):

    cleanconfig = self.cleanConf()
    
    ff = tempfile.TemporaryFile(mode = 'w+')      
    cleanconfig.write(ff)
    ff.seek(0)      
    str_config = ff.read()
    ff.close()
    return str_config

  def writeConf(self):
    cleanconfig = self.cleanConf()
    
    with open(self.configfilename, 'w+') as fh:
      cleanconfig.write(fh)
      fh.seek(0)
      str_config = fh.read()

    return str_config

  def createdata(self):
    data = self.data
    config = self.cleanConf()
    for section in config.sections():
      for key in config[section]:
        data[section + '.' + key] = config[section][key]
        
    data['wizard.id'] = '<xsl:value-of select='@id'/>'
    print (data)
    return data
    
  def writeJSON(self, filename):    
    print ('Write datamodel ...')
    content = json.dumps(self.createdata(), sort_keys=True, indent=2)
    with open(filename, 'w') as fh:
      fh.write(content)
      
class SessionNameCheckLineEdit(CheckLineEdit):

  wizard = None

  def __init__(self, parent=None):
    super(SessionNameCheckLineEdit, self).__init__(parent)
    
  def hasAcceptableInput(self):
    if self.wizard != None:
      if self.lineEdit.hasAcceptableInput() and self.lineEdit.text() != '':
        if self.wizard.sessionNameAlreadyUsed():
          self.labelMessage.setText("<span style='color:red'>Session name already in use !</span>")
        else:
          self.labelMessage.setText("")  
          return True      
    else:
      self.labelMessage.setText("")  
      return self.lineEdit.hasAcceptableInput() and self.lineEdit.text() != ''     

class <xsl:value-of select='replace(upper-case(@id),"WIZARD","")'/>Wizard(QtWidgets.QWizard):


    Page_<xsl:value-of select='first-page/@id'/> = 1

    <xsl:for-each select='//page'>
    Page_<xsl:value-of select='@id'/> = <xsl:value-of select='position() + 1'/>
    </xsl:for-each>

    Page_<xsl:value-of select='last-page/@id'/> = <xsl:value-of select='count(//page) + 2'/>
    
    def __init__(self, parent=None, templatesdir='./'):
        super(<xsl:value-of select='replace(upper-case(@id),"WIZARD","")'/>Wizard, self).__init__(parent)

        self._<xsl:value-of select='first-page/@id'/>Page = <xsl:value-of select='first-page/@id'/>Page(self)
        self.setPage(self.Page_<xsl:value-of select='first-page/@id'/>, self._<xsl:value-of select='first-page/@id'/>Page)
        
        <xsl:for-each select='//page'>
        self._<xsl:value-of select='@id'/>Page = <xsl:value-of select='@id'/>Page(self)
        self.setPage(self.Page_<xsl:value-of select='@id'/>, self._<xsl:value-of select='@id'/>Page)
        </xsl:for-each>
        
        self._<xsl:value-of select='last-page/@id'/>Page = <xsl:value-of select='last-page/@id'/>Page(self)
        self.setPage(self.Page_<xsl:value-of select='last-page/@id'/>, self._<xsl:value-of select='last-page/@id'/>Page)

        self.resize(<xsl:value-of select='width'/>,<xsl:value-of select='height'/>)
        self.datamodel = DataModel(self)
        self.datamodel.readConf()
        self.currentIdChanged.connect(self.enableButtons)
        self.templatesdir = templatesdir
        
    def enableButtons(self):
      id = self.currentId()
      if id == self.Page_<xsl:value-of select='first-page/@id'/> or id == self.Page_<xsl:value-of select='last-page/@id'/>:
        self.button(QtWidgets.QWizard.CustomButton1).setEnabled(False)
        self.button(QtWidgets.QWizard.CustomButton2).setEnabled(False)      
      else:
        self.button(QtWidgets.QWizard.CustomButton1).setEnabled(True)
        self.button(QtWidgets.QWizard.CustomButton2).setEnabled(True)              
                
    def defaults(self):
      if self.currentPage() != None:
        self.currentPage().defaults()
        
    def allFieldNames(self):
      return {s for page_id in self.pageIds() for s in self.page(page_id).field_names}

    def initFieldsOfSection(self):
      self.datamodel.initFieldsOfSection(self.currentPage())
      
    def cleanConfAsString(self):
      self.datamodel.cleanConfAsString()
            
    def updateUsers(self):
      self.datamodel.updateUsers()
      
    def sessionNameAlreadyUsed(self):
      self.datamodel.sessionNameAlreadyUsed()
    
class BasePage(QtWidgets.QWizardPage):
    
    field_names = set([])
    sectionName = None
    
    def __init__(self, parent=None):
        super(BasePage, self).__init__(parent)
    
    def registerField(self, name, *args, **kwargs):
        self.field_names.add(name)
        super().registerField(name, *args, **kwargs)

    def updateFieldsOfSection(self):
      self.wizard().datamodel.updateConf(self)
    
    def initFieldsOfSection(self):
      self.wizard().datamodel.initFieldsOfSection(self)      

class <xsl:value-of select='first-page/@id'/>Page(BasePage):
    def __init__(self, parent=None):
        super(<xsl:value-of select='first-page/@id'/>Page, self).__init__(parent)
        self.labelDescription = QtWidgets.QLabel()
        layout = QtWidgets.QVBoxLayout()
        layout.addWidget(self.labelDescription)
        self.setLayout(layout)
        self.sectionName = None

    def initializePage(self):
        self.setTitle('<xsl:value-of select='first-page/title'/>')
        self.labelDescription.setText('<xsl:value-of select='first-page/description'/>')

<xsl:for-each select='page'>

class <xsl:value-of select='@id'/>Page(BasePage):
    def __init__(self, parent=None):
        super(<xsl:value-of select='@id'/>Page, self).__init__(parent)
        self.sectionName = '<xsl:value-of select='@section-name'/>'
        
        <xsl:for-each select='field'>
        self._label_<xsl:value-of select='@id'/> = QtWidgets.QLabel()
        <xsl:choose>
        <xsl:when test='@type = "QLineEdit"'>
          <xsl:choose>
            <xsl:when test='input/@type = "filename"'>
        _validator_<xsl:value-of select='@id'/> = QtGui.QRegularExpressionValidator(filenameQregexp, self)
        self._<xsl:value-of select='@id'/>.setValidator(_validator_<xsl:value-of select='@id'/>)                        
            </xsl:when>
            <xsl:when test='input/@type = "directory"'>
        _validator_<xsl:value-of select='@id'/> = QtGui.QRegularExpressionValidator(directoryQregexp, self)
        self._<xsl:value-of select='@id'/>.setValidator(_validator_<xsl:value-of select='@id'/>)            
            </xsl:when>
            <xsl:when test='input/@type = "path"'>
        _validator_<xsl:value-of select='@id'/> = QtGui.QRegularExpressionValidator(pathQregexp, self)
        self._<xsl:value-of select='@id'/>.setValidator(_validator_<xsl:value-of select='@id'/>)            
            </xsl:when>
            <xsl:when test='input/@type = "regexp"'>
        _validator_<xsl:value-of select='@id'/> = QtGui.QRegularExpressionValidator(QtCore.QRegularExpression('<xsl:value-of select='format/input-regexp'/>'), self)
        self._<xsl:value-of select='@id'/>.setValidator(_validator_<xsl:value-of select='@id'/>)
            </xsl:when>
            <xsl:when test='input/@type = "range"'>
        _validator_<xsl:value-of select='@id'/> = QtGui.QIntValidator(<xsl:value-of select='format/min'/>,<xsl:value-of select='format/max'/>, self)            
        self._<xsl:value-of select='@id'/>.setValidator(_validator_<xsl:value-of select='@id'/>)
            </xsl:when>
            <xsl:otherwise>
            # GENERATION ERROR: unhandled format "<xsl:value-of select='@format'/>"
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test='@type = "QCheckBox"'>
        self._<xsl:value-of select='@id'/> = QtWidgets.QCheckBox(self)
        </xsl:when>
        <xsl:when test='@type = "PathLineEdit"'>
          <xsl:choose>
            <xsl:when test='input/@type = "filename"'>        
        self._<xsl:value-of select='@id'/> = PathLineEdit(self, filedialogtype=PathLineEdit.Type_File)
            </xsl:when>
            <xsl:when test='input/@type = "directory"'>
        self._<xsl:value-of select='@id'/> = PathLineEdit(self, filedialogtype=PathLineEdit.Type_Dir)
            </xsl:when>
          </xsl:choose>
        </xsl:when>
        <xsl:when test='@type = "CheckLineEdit"'>
        self._<xsl:value-of select='@id'/> = CheckLineEdit(self)        
          <xsl:choose>
            <xsl:when test='input/@type = "regexp"'>
        _validator_<xsl:value-of select='@id'/> = QtGui.QRegularExpressionValidator(QtCore.QRegularExpression('<xsl:value-of select='input/regexp'/>'), self)
        self._<xsl:value-of select='@id'/>.lineEdit.setValidator(_validator_<xsl:value-of select='@id'/>)
            </xsl:when>
            <xsl:when test='input/@type = "range"'>
        _validator_<xsl:value-of select='@id'/> = QtGui.QIntValidator(<xsl:value-of select='input/@min'/>,<xsl:value-of select='input/@max'/>, self)            
        self._<xsl:value-of select='@id'/>.lineEdit.setValidator(_validator_<xsl:value-of select='@id'/>)
            </xsl:when>
            <xsl:otherwise>
            # GENERATION ERROR: unhandled input/@type "<xsl:value-of select='input/@type'/>"
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test='@type = "SessionNameCheckLineEdit"'>
        self._<xsl:value-of select='@id'/> = SessionNameCheckLineEdit(self)        
        </xsl:when>
        <xsl:when test='@type = "QComboBox"'>
        self._<xsl:value-of select='@id'/> = QtWidgets.QComboBox(self)
        <xsl:for-each select='input/item'>
        self._<xsl:value-of select='../../@id'/>.addItem("<xsl:value-of select='@id'/>","<xsl:value-of select='@label'/>")
        </xsl:for-each>
        </xsl:when>
        <xsl:when test='@type = "UsersListEdit"'>
        self._<xsl:value-of select='@id'/> = UsersListEdit(self, property_hided='<xsl:value-of select='@id'/>'<xsl:if test="output/property_checked">, property_checked=None</xsl:if><xsl:if test="input/@max-count">, usercountmax=<xsl:value-of select='input/@max-count'/></xsl:if><xsl:if test="input/@inputs">, inputs=<xsl:value-of select='input/@inputs'/></xsl:if><xsl:if test="input/@outputs">,outputs=<xsl:value-of select='input/@outputs'/></xsl:if>)
        </xsl:when>
        </xsl:choose>
        </xsl:for-each>
        layout = QtWidgets.QVBoxLayout()
        <xsl:for-each select='field'>
        layout.addWidget(self._label_<xsl:value-of select='@id'/>)
        <xsl:choose>
        <xsl:when test='@type = "CheckLineEdit"'>
        layout.addLayout(self._<xsl:value-of select='@id'/>.layout())
        </xsl:when>
        <xsl:when test='@type = "SessionNameCheckLineEdit"'>
        layout.addLayout(self._<xsl:value-of select='@id'/>.layout())
        </xsl:when>
        <xsl:when test='@type = "PathLineEdit"'>
        layout.addLayout(self._<xsl:value-of select='@id'/>.layout())
        </xsl:when>
        <xsl:when test='@type = "UsersListEdit"'>
        self._<xsl:value-of select='@id'/>.addToLayout(layout)
        </xsl:when>
        <xsl:when test='@type = "QComboBox"'>
        layout.addWidget(self._<xsl:value-of select='@id'/>)
        </xsl:when>
        <xsl:when test='@type = "UsersListEdit"'>
        self._<xsl:value-of select='@id'/>.layout(layout) 
        </xsl:when>
        <xsl:otherwise>
        layout.addWidget(self._<xsl:value-of select='@id'/>)
        </xsl:otherwise>
        </xsl:choose>
        </xsl:for-each>
        
        self.setLayout(layout)
        
        <xsl:for-each select='field'>
        <xsl:choose>
        <xsl:when test='@type = "QComboBox"'>
        self.registerField(self.sectionName + '.<xsl:value-of select='@id'/>', self._<xsl:value-of select='@id'/>, "currentText")
        </xsl:when>
        <xsl:when test='@type = "PathLineEdit"  or @type = "CheckLineEdit" or @type = "SessionNameCheckLineEdit"'>
        self.registerField(self.sectionName + '.<xsl:value-of select='@id'/>', self._<xsl:value-of select='@id'/>.lineEdit)
        </xsl:when>
        
        <xsl:when test='@type = "UsersListEdit"'>
        </xsl:when>
        <xsl:otherwise>
        self.registerField(self.sectionName + '.<xsl:value-of select='@id'/>', self._<xsl:value-of select='@id'/>)
        </xsl:otherwise>
        </xsl:choose>
        </xsl:for-each>
      
    def initializePage(self):
        datamodel = self.wizard().datamodel
        data = datamodel.data
        config = datamodel.config
        self.initFieldsOfSection()
        <xsl:for-each select='field'>
        <xsl:if test='@type = "UsersListEdit"'>
        self._<xsl:value-of select='@id'/>.initialize(data['<xsl:value-of select='input/@list-id'/>'])
        self._<xsl:value-of select='@id'/>.readConf(config)
        </xsl:if>
        </xsl:for-each>
        self.setTitle('<xsl:value-of select='title'/>')
        <xsl:for-each select='field'>
        self._label_<xsl:value-of select='@id'/>.setText('<xsl:value-of select='label'/>')
        </xsl:for-each>
                              
    def validatePage(self):
        if <xsl:for-each select='field[not(@type="QComboBox") and not(@type="QCheckBox")]'><xsl:if test='position() != 1'><xsl:text> and </xsl:text></xsl:if>self._<xsl:value-of select='@id'/>.hasAcceptableInput()</xsl:for-each>:
          self.updateFieldsOfSection()
          datamodel = self.wizard().datamodel
          data = datamodel.data
          config = datamodel.config
          <xsl:for-each select='field'>
            <xsl:if test="output/@datamodel-id">
              <xsl:choose>
                <xsl:when test='@type = "UsersListEdit"'>
          self._<xsl:value-of select='@id'/>.updateConf(config,'<xsl:value-of select='output/@datamodel-id'/>')
                </xsl:when>
                <xsl:otherwise>
          data['<xsl:value-of select='output/@datamodel-id'/>'] = config['<xsl:value-of select='../@section-name'/>']['<xsl:value-of select='@id'/>']
                </xsl:otherwise>
              </xsl:choose>
            </xsl:if>
          </xsl:for-each>
          <xsl:for-each select='.//output[@split-seperator]'>
            <xsl:if test='../@type = "CheckLineEdit" or ../@type = "QLineEdit"'>
          data['<xsl:value-of select='@datamodel-id'/>'] = config['<xsl:value-of select='../../@section-name'/>']['<xsl:value-of select='../@id'/>'].split('<xsl:value-of select='@split-seperator'/>')
            </xsl:if>
          </xsl:for-each>
          print (data)
          return True
        return False
    
    def defaults(self):
      print ("Apply defaults")
      <xsl:for-each select='field'>
        <xsl:choose>
          <xsl:when test='@type = "UsersListEdit"'>
      for i in range(<xsl:value-of select='input/@max-count'/>):
        self.setField(self.sectionName + '.<xsl:value-of select='@id'/>' + str(i) + '-name-hide', '') 
        property_checked = ('<xsl:value-of select='output/@property_checked'/>' != '')
        inputs = <xsl:value-of select='input/@inputs'/>
        outputs = <xsl:value-of select='input/@outputs'/>
        if property_checked != None:
          self.setField(self.sectionName + '.<xsl:value-of select='@id'/>' + str(i) + '-checked-hide', '') 
        if inputs == True:
          self.setField(self.sectionName + '.<xsl:value-of select='@id'/>' + str(i) + '-inputs-hide', '') 
        if outputs == True:
          self.setField(self.sectionName + '.<xsl:value-of select='@id'/>' + str(i) + '-outputs-hide', '')
      
      listlabel = self.wizard().datamodel.data['<xsl:value-of select='output/@datamodel-id'/>']
      for i in range(len(listlabel)):
        self.setField(self.sectionName + '.<xsl:value-of select='@id'/>' + str(i) + '-name-hide', listlabel[i] ) 
          <xsl:for-each select='./default/item'>
            <xsl:if test='@checked'>
      self.setField(self.sectionName + '.<xsl:value-of select='@id'/>' + str(i) + '-checked-hide', <xsl:value-of select='@checked'/>) 
            </xsl:if>
            <xsl:if test='@inputs'>
      self.setField(self.sectionName + '.<xsl:value-of select='../../@id'/><xsl:value-of select='(position() - 1)'/>' + '-inputs-hide', '<xsl:value-of select='@inputs'/>' ) 
            </xsl:if>
            <xsl:if test='@outputs'>
      self.setField(self.sectionName + '.<xsl:value-of select='../../@id'/><xsl:value-of select='(position() - 1)'/>' + '-outputs-hide', '<xsl:value-of select='@outputs'/>' )       
            </xsl:if>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test='@type = "QCheckBox"'>
      self.setField(self.sectionName + '.<xsl:value-of select='@id'/>', '<xsl:value-of select='./default/@value'/>' == True) 
        </xsl:when>
        <xsl:otherwise>
      self.setField(self.sectionName + '.<xsl:value-of select='@id'/>', '<xsl:value-of select='./default/@value'/>') 
        </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
</xsl:for-each>
      
class <xsl:value-of select="last-page/@id"/>Page(BasePage):
    def __init__(self, parent=None):
      super(<xsl:value-of select="last-page/@id"/>Page, self).__init__(parent)
      self.labelDescription = QtWidgets.QLabel()
      self.textEdit = QtWidgets.QPlainTextEdit()
      layout = QtWidgets.QVBoxLayout()
      layout.addWidget(self.labelDescription)
      layout.addWidget(self.textEdit)
      
      self.setLayout(layout)
      self.sectionName = None

    def initializePage(self):
      self.setTitle('<xsl:value-of select='last-page/title'/>')
      self.labelDescription.setText('<xsl:value-of select='last-page/description'/>')
      
      self.textEdit.setPlainText(self.wizard().datamodel.cleanConfAsString())
      self.textEdit.setReadOnly(True)
      
    def validatePage(self):
      
      datamodel = self.wizard().datamodel
      if not (datamodel.sessionNameAlreadyUsed()):
        datamodel.writeConf()
        
        tmpdir = tempfile.mkdtemp()      
        outdir = datamodel.raysession_path
        datamodeldir = tmpdir + os.sep + 'etc' + os.sep + 'default'
        os.makedirs(datamodeldir)
        datamodelfile= datamodeldir + os.sep + 'datamodel.json'
        self.wizard().datamodel.writeJSON(datamodelfile)
        
        templatedir = self.wizard().templatesdir + os.sep + '<xsl:value-of select='@id'/>'
        sys.path.append(templatedir)

        from tmpl_<xsl:value-of select='lower-case(@id)'/> import RaySessionTemplate

        
        print ('--' + str(datamodelfile) + '\n--' + str(templatedir) + '\n--' + str(tmpdir) + '\n--' + str(outdir) + '\n')
        
        if RaySessionTemplate().fillInTemplate(datamodelfile, templatedir, tmpdir, outdir) == 0:          
          QtWidgets.QMessageBox.information(self,
                                            "RaySessionn creation ...",
                                            "The RaySession has been successfully created.")
        
        return True
      else:
        QtWidgets.QMessageBox.critical(self,
                                            "RaySessionn creation ...",
                                            "The RaySession name is already in use ! Please set another one.")
      return False
    
if __name__ == '__main__':
    import sys
    
    app = QtWidgets.QApplication(sys.argv)
    wizard = <xsl:value-of select='replace(upper-case(@id),"WIZARD","")'/>Wizard(templatesdir=sys.argv[1])
    layout = [QtWidgets.QWizard.CustomButton1, QtWidgets.QWizard.CustomButton2, QtWidgets.QWizard.BackButton, QtWidgets.QWizard.CancelButton, QtWidgets.QWizard.NextButton, QtWidgets.QWizard.FinishButton]
    wizard.setButtonLayout(layout);    
    wizard.setButtonText(QtWidgets.QWizard.CustomButton1, "Defaults")
    wizard.setButtonText(QtWidgets.QWizard.CustomButton2, "Read wizard.conf")
    wizard.show()
    wizard.button(QtWidgets.QWizard.CustomButton1).clicked.connect(wizard.defaults)
    wizard.button(QtWidgets.QWizard.CustomButton2).clicked.connect(wizard.initFieldsOfSection)
    
    sys.exit(app.exec_())

</xsl:template>

</xsl:stylesheet>
