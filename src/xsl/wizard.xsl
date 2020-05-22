<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">#!/usr/bin/env python

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
import getopt

# Project files
from ui_userslistedit import UsersListEdit
from ui_checklineedit import CheckLineEdit
from ui_pathlineedit import PathLineEdit
from ui_radiobuttondelegate import RadioButtonDelegate

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


  data = {}
  
  def __init__(self, wizard):
    self.wizard = wizard
    self.config = None
    self.configfilename = '<xsl:value-of select='@id'/>.conf'
    self.raysession_root = os.environ.get('RAY_SESSION_ROOT', '~/"Ray Sessions"')
    self.raysession_path = None
    self.registeredkey = {}
    self.allowedSections = []
  
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

  def jackInputs(self,inputtype,content):
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

  def jackOutputs(self,inputtype,content):
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

  def leftJackInputs(self, content):
    return self.jackInputs('L', content)

  def rightJackInputs(self, content):
    return self.jackInputs('R', content)
    
  def leftJackOutputs(self, content):
    return self.jackOutputs('L', content)
  
  def rightJackOutputs(self, content):
    return self.jackOutputs('R', content)

  def sessionNameAlreadyUsed(self):    
    self.raysession_path = self.raysession_root + os.sep + self.wizard.field('<xsl:value-of select='//field[@id = "raysession_name"]/../@section-name'/>.raysession_name')
    if os.path.isdir(self.raysession_path):
      print('Directory "%s" already exist ! Choose another name or delete it first.' % self.raysession_path ) 
      return True
    else:
      print('Directory "%s" does not exist.' % self.raysession_path ) 
      return False

  def cleanConf(self, allFieldNames):
    sections = self.allowedSections
    new_config = configparser.ConfigParser({}, collections.OrderedDict)
    for section in sections:
      new_config[section]={}
      for ckey in self.config[section]:
        fieldkey = section + '.' + ckey
        if (fieldkey  in allFieldNames() or (section in self.registeredkey and ckey in self.registeredkey[section])) and not ('-hide' in ckey):
          if self.config[section][ckey] != None and self.config[section][ckey] != '':
            new_config[section][ckey] = self.config[section][ckey]
      new_config._sections[section] = collections.OrderedDict(sorted(new_config._sections[section].items(), key=lambda t: t[0]))
    
    return new_config

  def cleanConfAsString(self, allFieldNames):

    cleanconfig = self.cleanConf(allFieldNames)
    
    ff = tempfile.TemporaryFile(mode = 'w+')      
    cleanconfig.write(ff)
    ff.seek(0)      
    str_config = ff.read()
    ff.close()
    
    print (str_config)
    return str_config

  def writeConf(self, allFieldNames):
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
    return content
      
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

  
    pageSteps = []
    
    (Page_<xsl:value-of select='first-page/@id'/>,
    <xsl:for-each select='//page'>
    Page_<xsl:value-of select='@id'/>,
    </xsl:for-each>
    Page_<xsl:value-of select='last-page/@id'/>) = range(<xsl:value-of select='count(//page) + 2'/>)
    
    pagenameByIdx = {}
    
    def __init__(self, parent=None, templatedir='.', jsonfilename=None, startguioption=False):
        super(<xsl:value-of select='replace(upper-case(@id),"WIZARD","")'/>Wizard, self).__init__(parent)

        self.startguioption = startguioption
        self.startgui = False

        self._<xsl:value-of select='first-page/@id'/>Page = <xsl:value-of select='first-page/@id'/>Page(self)
        self.setPage(self.Page_<xsl:value-of select='first-page/@id'/>, self._<xsl:value-of select='first-page/@id'/>Page)
        self.pagenameByIdx[self.Page_<xsl:value-of select="first-page/@id"/>] = '<xsl:value-of select="first-page/@id"/>'
        
        <xsl:for-each select='//page'>
        self._<xsl:value-of select='@id'/>Page = <xsl:value-of select='@id'/>Page(self)
        self.setPage(self.Page_<xsl:value-of select='@id'/>, self._<xsl:value-of select='@id'/>Page)
        self.pagenameByIdx[self.Page_<xsl:value-of select="@id"/>] = '<xsl:value-of select="@id"/>'
        </xsl:for-each>
        
        self._<xsl:value-of select='last-page/@id'/>Page = <xsl:value-of select='last-page/@id'/>Page(self)
        self.setPage(self.Page_<xsl:value-of select='last-page/@id'/>, self._<xsl:value-of select='last-page/@id'/>Page)
        self.pagenameByIdx[self.Page_<xsl:value-of select="last-page/@id"/>] ='<xsl:value-of select="last-page/@id"/>'

        self.resize(<xsl:value-of select='width'/>,<xsl:value-of select='height'/>)
        self.datamodel = DataModel(self)
        self.datamodel.readConf()
        self.currentIdChanged.connect(self.enableButtons)
        self.templatedir = templatedir
        self.jsonfilename = jsonfilename
        self.registeredPage = []
        self.stepindex = 0
        
        self.pageSteps.append(self.Page_<xsl:value-of select="first-page/@id"/>)
        <xsl:for-each select="page[@use = 'required']">
        self.pageSteps.append(self.Page_<xsl:value-of select="@id"/>)
        </xsl:for-each>
        self.pageSteps.append(self.Page_<xsl:value-of select="last-page/@id"/>)
        self.setStartId(self.Page_<xsl:value-of select="first-page/@id"/>)
        self.printPageSteps()
        
    def printPageSteps(self):
      id = self.currentId()
      print (self.visitedPages())
      for i in range(len(self.pageSteps)):
        if self.pageSteps[i] == id:
          print ("*(" + str(self.pageSteps[i]) + ")" + self.pagenameByIdx[self.pageSteps[i]])        
        else:
          print ("(" + str(self.pageSteps[i]) + ")" + self.pagenameByIdx[self.pageSteps[i]])
        
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
      return self.datamodel.cleanConfAsString(self.allFieldNames)

    def updateConfSections(self):
      sections=['wizard']
      if not('wizard' in self.datamodel.config.sections()):
        self.datamodel.config['wizard'] = {}
      for pageid in self.pageSteps:
        sectionname = self.page(pageid).sectionName
        if sectionname:
          sections.append(sectionname)
        
      self.datamodel.allowedSections = sections
      print ('Sections allowed:')
      print (self.datamodel.allowedSections)
      
    def writeConf(self):
      self.datamodel.writeConf(self.allFieldNames)
      
    def sessionNameAlreadyUsed(self):
      self.datamodel.sessionNameAlreadyUsed()
      
    def nextId(self):
      id = self.currentId()
      for i in range(len(self.pageSteps) - 1):
        if self.pageSteps[i] == id:
          return self.pageSteps[i+1]
      return -1

    def requires(self):
      programs = []
      <xsl:for-each select="requires">
      programs.append('<xsl:value-of select="@executable"/>')
      </xsl:for-each>
      self.datamodel.data['wizard.requirelist'] = programs
      for pageid in self.pageSteps:
        self.page(pageid).requires()
      return programs
    
    def setVariables(self):
      <xsl:for-each select="set">
      self.datamodel.data['wizard.<xsl:value-of select="@id"/>'] = '<xsl:value-of select='@value'/>'
      </xsl:for-each>
      for pageid in self.pageSteps:
        self.page(pageid).setVariables()

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
      
    def nextId(self):
      return self.wizard().nextId()

    def setVariables(self):
      pass
      
    def requires(self):
      return []      
    
class <xsl:value-of select='first-page/@id'/>Page(BasePage):
    def __init__(self, parent=None):
        super(<xsl:value-of select='first-page/@id'/>Page, self).__init__(parent)
        self.labelDescription = QtWidgets.QLabel()
        layout = QtWidgets.QVBoxLayout()
        layout.addWidget(self.labelDescription)
        self.checkStartgui = QtWidgets.QCheckBox()
        layout.addWidget(self.checkStartgui)
        self.labelMessage = QtWidgets.QLabel()
        layout.addWidget(self.labelMessage)
        self.treeApplications = QtWidgets.QTreeWidget()
        self.treeApplications.setItemDelegate(RadioButtonDelegate())
        self.treeApplications.setSelectionMode(QtWidgets.QAbstractItemView.MultiSelection)
        layout.addWidget(self.treeApplications)
        self.setLayout(layout)
        self.sectionName = None
        self.hashSteps = {}

        self.wizard()

        
    def initializePage(self):
        self.setTitle('<xsl:value-of select='first-page/title'/>')
        self.labelDescription.setText('<xsl:value-of select='first-page/description'/>')
        if self.wizard().startguioption:
          self.checkStartgui.setText('Check if you want to start RaySession GUI once the RaySession document has been created')
          self.checkStartgui.show()
        else:
          self.checkStartgui.hide()
        self.labelMessage.setText('')
        datamodel = self.wizard().datamodel
        <xsl:for-each select="//field[@type='UsersListEdit']">
        <xsl:if test="output/@datamodel-id">
        datamodel.data['<xsl:value-of select="output/@datamodel-id"/>'] = []
        </xsl:if>
        </xsl:for-each>
                
        sectionnames = []
        try:
          sectionnames = self.wizard().datamodel.config['wizard']['sectionnames'].split(',')
        except:
          print("wizard.pages not found")
          pass
          
        group = None
        self.hashSteps = {}
        allrequired = True
        <xsl:for-each select="//page">
          <xsl:choose>
            <xsl:when test="parent::node()/name() = 'page-group'">
        allrequired = False
        if not(group):
          group = QtWidgets.QTreeWidgetItem(self.treeApplications)
          group.setText(0, "<xsl:value-of select="../short-title"/>")
          group.setFlags(QtCore.Qt.ItemIsUserCheckable | QtCore.Qt.ItemIsSelectable | QtCore.Qt.ItemIsEnabled)
          group.setCheckState(0, QtCore.Qt.Unchecked)
          
        child = QtWidgets.QTreeWidgetItem(group)
        child.setFlags(QtCore.Qt.ItemIsUserCheckable | QtCore.Qt.ItemIsSelectable | QtCore.Qt.ItemIsEnabled)
        child.setText(0, "<xsl:value-of select="short-title"/>")
        child.setText(1, "<xsl:value-of select="@section-name"/>")
        if child.text(1) in sectionnames:
          child.setCheckState(0, QtCore.Qt.Checked)
          group.setCheckState(0, QtCore.Qt.Checked)
        else:
          child.setCheckState(0, QtCore.Qt.Unchecked)
          
        self.hashSteps['<xsl:value-of select="short-title"/>'] = self.wizard().Page_<xsl:value-of select="@id"/>
            </xsl:when>
            <xsl:when test="not(parent::node()/name() = 'page-group')">
        group = None
        parent = QtWidgets.QTreeWidgetItem(self.treeApplications)
        parent.setText(0, "<xsl:value-of select="short-title"/>")
        parent.setText(1, "<xsl:value-of select="@section-name"/>")
        parent.setFlags(QtCore.Qt.ItemIsUserCheckable | QtCore.Qt.ItemIsSelectable | QtCore.Qt.ItemIsEnabled)
          <xsl:if test="@use = 'optional'">
        allrequired = False
        if parent.text(1) in sectionnames:
          parent.setCheckState(0, QtCore.Qt.Checked)
        else:
          parent.setCheckState(0, QtCore.Qt.Unchecked)
          </xsl:if>
          <xsl:if test="@use = 'required'">
        parent.setCheckState(0, QtCore.Qt.Checked)
        parent.setDisabled(True)
          </xsl:if>
        self.hashSteps['<xsl:value-of select="short-title"/>'] = self.wizard().Page_<xsl:value-of select="@id"/>
            </xsl:when>
          </xsl:choose>
        </xsl:for-each>
        if allrequired:
          self.labelMessage.setText('All steps are required.')
          
    def validatePage(self):
        if self.wizard().startguioption:
          self.wizard().startgui = self.checkStartgui.isChecked()
        
        self.wizard().pageSteps = []
        pageSteps = self.wizard().pageSteps
        pagenames = []
        pageSteps.append(self.wizard().Page_<xsl:value-of select="//first-page/@id"/>)
        iterator = QtWidgets.QTreeWidgetItemIterator(self.treeApplications, QtWidgets.QTreeWidgetItemIterator.Checked)
        while iterator.value():
          item = iterator.value()
          if item.parent():
            if item.parent().checkState(0):
              pageSteps.append(self.hashSteps[item.text(0)])
              pagenames.append(item.text(1))
          elif item.childCount() == 0:          
            pageSteps.append(self.hashSteps[item.text(0)])   
            pagenames.append(item.text(1))
          iterator += 1
        pageSteps.append(self.wizard().Page_<xsl:value-of select="//last-page/@id"/>)
        self.wizard().updateConfSections()
        self.wizard().datamodel.registerkey('wizard','sectionnames')
        self.wizard().datamodel.config['wizard']['sectionnames'] = ','.join(pagenames)
        self.wizard().datamodel.data['wizard.sectionnamelist'] = pagenames
        self.wizard().setVariables()
        self.wizard().requires()
        print("Selected pages:")
        self.wizard().stepindex = 0
        self.wizard().printPageSteps()
        return True

<xsl:for-each select='//page'>

class <xsl:value-of select='@id'/>Page(BasePage):
    def __init__(self, parent=None):
        super(<xsl:value-of select='@id'/>Page, self).__init__(parent)
        self.sectionName = '<xsl:value-of select='@section-name'/>'
        
        <xsl:for-each select='field'>
        self._label_<xsl:value-of select='@id'/> = QtWidgets.QLabel()
        <xsl:choose>
        <xsl:when test='@type = "QLineEdit"'>
        self._<xsl:value-of select='@id'/> = QtWidgets.QLineEdit(self)
          <xsl:choose>
            <xsl:when test='input/@type = "None"'>
            </xsl:when>
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
        _validator_<xsl:value-of select='@id'/> = QtGui.QRegularExpressionValidator(QtCore.QRegularExpression('<xsl:value-of select='input/@regexp'/>'), self)
        self._<xsl:value-of select='@id'/>.setValidator(_validator_<xsl:value-of select='@id'/>)
            </xsl:when>
            <xsl:when test='input/@type = "range"'>
        _validator_<xsl:value-of select='@id'/> = QtGui.QIntValidator(<xsl:value-of select='input/@min'/>,<xsl:value-of select='input/@max'/>, self)            
        self._<xsl:value-of select='@id'/>.setValidator(_validator_<xsl:value-of select='@id'/>)
            </xsl:when>
            <xsl:otherwise>
            # GENERATION ERROR: unhandled input/@type "<xsl:value-of select='input/@type'/>" for <xsl:value-of select='@type'/>
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
            # GENERATION ERROR: unhandled input/@type "<xsl:value-of select='input/@type'/>" for <xsl:value-of select='@type'/>
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
        <xsl:when test='@type = "QListWidget"'>
        self._<xsl:value-of select='@id'/> = QtWidgets.QListWidget(self)
        <xsl:for-each select='input/item'>
        self._<xsl:value-of select='../../@id'/>.addItem("<xsl:value-of select='@id'/>","<xsl:value-of select='@label'/>")
        </xsl:for-each>
        </xsl:when>
        <xsl:when test='@type = "UsersListEdit"'>
        self._<xsl:value-of select='@id'/> = UsersListEdit(self, property_name='<xsl:value-of select='@id'/>'<xsl:if test="input/@max-count">, countmax=<xsl:value-of select='input/@max-count'/></xsl:if><xsl:if test="input/@min">, minchecked=<xsl:value-of select="input/@min"/></xsl:if><xsl:if test="input/@max">, maxchecked=<xsl:value-of select="input/@max"/></xsl:if><xsl:if test="output/@property-checked-name">, property_checked='<xsl:value-of select="output/@property-checked-name"/>'</xsl:if><xsl:if test="input/@jack-inputs">, jack_inputs=<xsl:value-of select='input/@jack-inputs'/></xsl:if><xsl:if test="not(input/@jack-inputs)">, jack_inputs=False</xsl:if><xsl:if test="input/@jack-outputs">,jack_outputs=<xsl:value-of select='input/@jack-outputs'/></xsl:if><xsl:if test="not(input/@jack-outputs)">,jack_outputs=False</xsl:if>)
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
            <xsl:if test="output/@datamodel-id or output/@property-checked-name">
              <xsl:choose>
                <xsl:when test='@type = "UsersListEdit"'>
          self._<xsl:value-of select='@id'/>.updateConf(config,<xsl:if test="output/@datamodel-id">'<xsl:value-of select='output/@datamodel-id'/>'</xsl:if><xsl:if test="not(output/@datamodel-id)">None</xsl:if>)
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
        self._<xsl:value-of select='@id'/>.setFieldName(i, '') 
              <xsl:if test='@checked and ../../output/@property-checked-name'>
        self._<xsl:value-of select='@id'/>.setFieldCheck(<xsl:value-of select='(position() - 1)'/>, False) 
              </xsl:if>
              <xsl:if test='@jack-inputs'>
        self._<xsl:value-of select='@id'/>.setFieldJackInputs(i, '') 
              </xsl:if>
              <xsl:if test='@jack-outputs'>
        self._<xsl:value-of select='@id'/>.setFieldJackOutputs(i, '') 
              </xsl:if>
      
      listlabel = self.wizard().datamodel.data['<xsl:value-of select='input/@list-id'/>']
      for i in range(len(listlabel)):
        self.setField(self.sectionName + '.<xsl:value-of select='@id'/>' + str(i) + '-name-hide', listlabel[i] )
          <xsl:for-each select='./default/item'>
            <xsl:if test='@checked and ../../output/@property-checked-name'>
      self._<xsl:value-of select='../../@id'/>.setFieldCheck(<xsl:value-of select='(position() - 1)'/>, <xsl:value-of select='@checked'/>) 
            </xsl:if>
            <xsl:if test='@jack-inputs'>
      self._<xsl:value-of select='../../@id'/>.setFieldJackInputs(<xsl:value-of select='(position() - 1)'/>, '<xsl:value-of select='@jack-inputs'/>') 
            </xsl:if>
            <xsl:if test='@jack-outputs'>
      self._<xsl:value-of select='../../@id'/>.setFieldJackOutputs(<xsl:value-of select='(position() - 1)'/>, '<xsl:value-of select='@jack-outputs'/>') 
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
      
    def requires(self):
      programs = []
      <xsl:for-each select="requires">
      programs.append('<xsl:value-of select="@executable"/>')
      </xsl:for-each>
      self.wizard().datamodel.data['<xsl:value-of select="@section-name"/>.requirelist'] = programs
      return programs
    
    def setVariables(self):
      <xsl:for-each select="set">
      self.wizard().datamodel.data['<xsl:value-of select='../@section-name'/>.<xsl:value-of select="@id"/>'] = '<xsl:value-of select='@value'/>'
      </xsl:for-each>
      pass
    
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
      
      print ("Allowed Sections:")
      print (self.wizard().datamodel.allowedSections)
      str_conf = self.wizard().cleanConfAsString()  
      self.textEdit.setPlainText(str_conf)
      self.textEdit.setReadOnly(True)
      
    def validatePage(self):
      
      datamodel = self.wizard().datamodel
      if not (datamodel.sessionNameAlreadyUsed()):
        self.wizard().writeConf()
        
        tmpdir = tempfile.mkdtemp()      
        outdir = datamodel.raysession_path
        if self.wizard().jsonfilename == None:
          tmp = tempfile.NamedTemporaryFile()
          datamodelfile=tmp.name
        else:
          datamodelfile = self.wizard().jsonfilename
        
        print(self.wizard().datamodel.writeJSON(datamodelfile))
          
        templatedir = self.wizard().templatedir

        if templatedir not in sys.path:
          print ("adding %s to sys.path" % templatedir)
          sys.path.append(templatedir)

        print ('sys.path' + str(sys.path))
        print ('--' + str(datamodelfile) + '\n--' + str(templatedir) + '\n--' + str(tmpdir) + '\n')

        
        #from tmpl_<xsl:value-of select='lower-case(@id)'/> import RaySessionTemplate        
        from tmpl_wizard import RaySessionTemplate        
        if RaySessionTemplate().fillInTemplate(datamodelfile, templatedir, tmpdir, startgui=self.wizard().startgui) == 0:          
          QtWidgets.QMessageBox.information(self,
                                            "RaySessionn creation ...",
                                            "The RaySession has been successfully created.")
        
        return True
      else:
        QtWidgets.QMessageBox.critical(self,
                                            "RaySessionn creation ...",
                                            "The RaySession name is already in use ! Please set another one.")
      return False

      
def usage():
  print ("Usage:")
  print ("<xsl:value-of select="@id"/>.py [options)")
  print ("   -h|--help              : print this help text")
  print ("   -d                     : debug information")
  print ("   -j|--write-json-file   : set the JSON file to write. It is used to fill the template and contains user inputs and wizard outputs variables.")
  print ("   -t|--template-dir      : set the template directory that contains the template related to this wizard.")
  print ("   -s|--start-gui-option  : The wizard will display an option for starting raysession software at the end of the document creation.")
  
if __name__ == '__main__':
  jsonfilename = None
  templatedir = 'xxx-TEMPLATE_DIR-xxx'
  startguioption = False
  import sys
  try:                                
    opts, args = getopt.getopt(sys.argv[1:], "hj:t:ds", ["help", "write-json-file=","template-dir=","debug","start-gui-option"])
    print ("args list: ")
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
    elif opt in ("-j", "--write-json-file"):
      jsonfilename = arg
      print ("will write a json file '%s' when finishing the wizard steps." % jsonfilename)
    elif opt in ("-t", "--template-dir"):
      templatedir = arg
      print ("Template dir is '%s'" % templatedir)
    elif opt in ("-s", "--start-gui-option"):
      startguioption=True
  
  app = QtWidgets.QApplication(sys.argv)
  wizard = <xsl:value-of select='replace(upper-case(@id),"WIZARD","")'/>Wizard(templatedir=templatedir, jsonfilename=jsonfilename, startguioption=startguioption)
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
