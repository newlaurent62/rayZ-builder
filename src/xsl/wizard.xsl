<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text" encoding="utf-8" indent="yes" />
<xsl:template match="/wizard">#!/usr/bin/env python

# libs
from PyQt5 import QtCore
from PyQt5 import QtGui
from PyQt5.QtCore import pyqtProperty
from PyQt5 import QtWidgets
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
import shlex
import getopt
import traceback
import pprint

# Project files
from rayZ_ui import *

_debug = None

hostnameOrIPre = "^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|((([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9])))$"
hostnameOrIPQregexp = QtCore.QRegularExpression(hostnameOrIPre)

pathre = "^(\\/(([ A-Za-z0-9-_+]|\\.)+\\/)*([A-Za-z0-9_-]|\\.)+)$"
pathQregexp = QtCore.QRegularExpression(pathre)
directoryre = "^(\\/(([ A-Za-z0-9-_+]|\\.)+\\/)*([A-Za-z0-9_-]|\\.)+)$"
directoryQregexp = QtCore.QRegularExpression(directoryre)
filenamere = "^([A-Za-z0-9_\- ]|\\.)+$"
filenameQregexp = QtCore.QRegularExpression(filenamere)
sessionnamere = "^((?!--)([ _A-Za-z0-9-]|\\.))+$"
sessionNameQregexp = QtCore.QRegularExpression(sessionnamere)
nameAndPasswordre = "^((?!--)([_A-Za-z0-9-]|\\.))+$"
nameAndPasswordQregexp = QtCore.QRegularExpression(nameAndPasswordre)
usersre = "^((?!--)([_A-Za-z0-9-]|\\.)+)(,((?!--)([_A-Za-z0-9-]|\\.)+))*$"
usersQregexp = QtCore.QRegularExpression(usersre)

jackinputmonore = "^(((([a-zA-Z]\w*):)?([0-9]+))(,((([a-zA-Z]\w*):)?([0-9]+)))*-&gt;(L)\s*)+$"
jackinputstereore = "^(((([a-zA-Z]\w*):)?([0-9]+))(,((([a-zA-Z]\w*):)?([0-9]+)))*-&gt;(LR|L|R)\s*)+$"
jackoutputmonore = "^((L)-&gt;(([a-zA-Z]\w*):)?([0-9]+)(,(([a-zA-Z]\w*):)?([0-9]+))*\s*)+$"
jackoutputstereore = "^((LR|L|R)-&gt;(([a-zA-Z]\w*):)?([0-9]+)(,(([a-zA-Z]\w*):)?([0-9]+))*\s*)+$"
jackinputmonoQregexp = QtCore.QRegularExpression(jackinputmonore)
jackinputstereoQregexp = QtCore.QRegularExpression(jackinputstereore)
jackoutputmonoQregexp = QtCore.QRegularExpression(jackoutputmonore)
jackoutputstereoQregexp = QtCore.QRegularExpression(jackoutputstereore)

class DataModel:


  data = {}
  
  def __init__(self, wizard, session_root, conffilename):
    self.wizard = wizard
    self.config = None
    self.configfilename = conffilename
    self.session_path = None
    self.registeredkey = {}
    self.allowedSections = []
    self.session_root = session_root
    self.session_name = None
  
  def readConf(self):
    config = configparser.ConfigParser()
    if os.path.isfile(self.configfilename):      
      if _debug:
        print ('Reading ' + self.configfilename)
      config.read(self.configfilename)
      if 'wizard' in config.sections() and 'id' in config['wizard']:
        if not (config['wizard']['id'] == '<xsl:value-of select="@id"/>'):
          QtWidgets.QMessageBox.critical(self,
                                            "Wizard loading ...",
                                            "The conf file (%s) has not been built by this wizard (%s)" % (self.configfilename, '<xsl:value-of select="@id"/>'))
          
          raise Exception('The %s file is not has not been built by %s wizard !' % (self.configfilename, '<xsl:value-of select="@id"/>'))
      else:
        if _debug:
          print ('wizard.id is missing ... Try to use %s anyway !' % self.configfilename)
    
    self.config = config
    self.config
   
  def registerkey(self, sectionName, key):
    key = key.lower()
    if not (sectionName in self.registeredkey):
      self.registeredkey[sectionName] = []
    if key not in self.registeredkey[sectionName]:
      self.registeredkey[sectionName].append(key)
    if _debug:
      print ('++key %s registered in section %s' % (key,sectionName))
      
  def removeRegiteredKey(self, section, property_hided):
    r = []
    if section in self.registeredkey:
      for key in self.registeredkey[section]:
        if key.startswith(property_hided):
          r.append(key)
          
    for key in r:
      self.registeredkey[section].remove(key)
      datakey = section + '.' + key
      if datakey in self.data:
        del self.data[datakey]
      datakey = section + '.' + key + 'list'
      if datakey in self.data:
        del self.data[datakey]

  def cleanConf(self, allFieldNames):
    sections = self.allowedSections
    
    if _debug:
      print ('[==== CleanConf')
      print ('allowedSections:')
      print (sections)
      print ('---')
      print ('registered keys:')
      print (self.registeredkey)
      print ('---')
  
    new_config = configparser.ConfigParser({}, collections.OrderedDict)
    for section in sections:
      new_config[section]={}
      for ckey in self.config[section]:
        fieldkey = section + '.' + ckey
        if ((allFieldNames and fieldkey in allFieldNames) or (section in self.registeredkey and ckey in self.registeredkey[section])) and not ckey.endswith('-hide'):
          if self.config[section][ckey] != None and self.config[section][ckey].strip() != '':
            new_config[section][ckey] = self.config[section][ckey]
      new_config._sections[section] = collections.OrderedDict(sorted(new_config._sections[section].items(), key=lambda t: t[0]))
    
    if _debug:
      self.printConf()
      print (']==== CleanConf')
    return new_config

  def printConf(self):
    ff = tempfile.TemporaryFile(mode = 'w+')      
    self.config.write(ff)
    ff.seek(0)      
    str_config = ff.read()
    ff.close()    
    print (str_config)
    
  def cleanConfAsString(self, allFieldNames):

    cleanconfig = self.cleanConf(allFieldNames)
    
    ff = tempfile.TemporaryFile(mode = 'w+')      
    cleanconfig.write(ff)
    ff.seek(0)      
    str_config = ff.read()
    ff.close()
    
    if _debug:
      print (str_config)
    return str_config

  def writeConf(self, allFieldNames):
    cleanconfig = self.cleanConf(allFieldNames)
    
    with open(self.configfilename, 'w+') as fh:
      cleanconfig.write(fh)
      fh.seek(0)
      str_config = fh.read()

    return str_config

  def createdata(self, allFieldNames):
    data = self.data
    config = self.cleanConf(allFieldNames)
    for section in config.sections():
      for key in config[section]:
        data[section + '.' + key] = config[section][key]
        
    data['wizard.id'] = '<xsl:value-of select='@id'/>'
    return data
    
  def writeJSON(self, filename, allFieldNames):    
    if _debug:
      print ('Write datamodel ...')
    content = json.dumps(self.createdata(allFieldNames), sort_keys=True, indent=2)
    with open(filename, 'w') as fh:
      fh.write(content)
    return content

  def isSessionNameAlreadyUsed(self, session_name):    
    self.session_path = self.session_root + os.sep + session_name
    if os.path.isdir(self.session_path):
      if _debug:
        print('Directory "%s" already exist ! Choose another name or delete it first.' % self.session_path ) 
      return True
    else:
      self.session_name = session_name
      return False

  def sessionNameAlreadyUsed(self):
    return self.isSessionNameAlreadyUsed(self.session_name)
    
class SessionWizard(QtWidgets.QWizard):

  
    pageSteps = []
    
    (Page_<xsl:value-of select='first-page/@id'/>,
    <xsl:for-each select='//page'>
    Page_<xsl:value-of select='@id'/>,
    </xsl:for-each>
    Page_<xsl:value-of select='last-page/@id'/>) = range(<xsl:value-of select='count(//page) + 2'/>)
    
    pagenameByIdx = {}
    
    def __init__(self, parent=None, jsonfilename=None, startguioption=False, session_manager="ray_control", configfilename='<xsl:value-of select='@id'/>.conf'):
        super(SessionWizard, self).__init__(parent)

        
        self._id = '<xsl:value-of select='@id'/>'
        self._title = '<xsl:value-of select='@title'/>'
        
        
        # Initialize DataModel
        session_root = ''
        if session_manager == 'nsm':
          try:
            session_root = os.environ['NSM_SESSION_ROOT'].replace('"','')
          except:
            pass
          if session_root == '':
            session_root = os.environ['HOME'] + os.sep + 'NSM Sessions'
        else:
          try:
            session_root = os.environ['RAY_SESSION_ROOT'].replace('"','')
          except:
            pass
          if session_root == '':
            session_root = os.environ['HOME'] + os.sep + 'Ray Sessions'
        
        session_root = session_root.replace('"','')
        
        if _debug:
          print ('session_root:"' + session_root + '"') 

        self.datamodel = DataModel(self, session_root, configfilename)
        self.datamodel.readConf()

        self.startguioption = startguioption
        self.startgui = False
        
        # Create Wizard Pages

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
  
        self.currentIdChanged.connect(self.enableButtons)
        self.jsonfilename = jsonfilename
        self.session_manager = session_manager
        self.registeredPage = []
        self.stepindex = 0
        
        self.pageSteps.append(self.Page_<xsl:value-of select="first-page/@id"/>)
        <xsl:for-each select="page[@use = 'required']">
        self.pageSteps.append(self.Page_<xsl:value-of select="@id"/>)
        </xsl:for-each>
        self.pageSteps.append(self.Page_<xsl:value-of select="last-page/@id"/>)
        self.setStartId(self.Page_<xsl:value-of select="first-page/@id"/>)
        self.printPageSteps()

        if self.session_manager == 'nsm':
          self.session_type = 'NSM'
        elif self.session_manager.startswith('ray'):
          self.session_type = 'RAY'
          
        self.updateTitle(None)

    def updateTitle(self,session_name):
      if session_name:
        self.setWindowTitle('Create ' + self.session_type + ' session ['+ session_name + ']')
      else:
        self.setWindowTitle('Create ' + self.session_type + ' session')
        
    def printPageSteps(self):
      id = self.currentId()
      if _debug:
        print (self.visitedPages())
      for i in range(len(self.pageSteps)):
        if self.pageSteps[i] == id:
          if _debug:
            print ("*(" + str(self.pageSteps[i]) + ")" + self.pagenameByIdx[self.pageSteps[i]])        
        else:
          if _debug:
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

    def readData(self):
      if self.currentPage() != None:
        self.currentPage().readData(self.datamodel.config, self.datamodel)

    def allFieldNames(self):
      field_names = []
      for page_id in self.pageIds():
        for f in self.page(page_id).field_names:
          if f not in field_names:
            field_names.append(f)
      return field_names
      
    def cleanConfAsString(self):
      return self.datamodel.cleanConfAsString(self.allFieldNames())

    def writeJSON(self, datamodelfile):
      return self.datamodel.writeJSON(datamodelfile, self.allFieldNames())
      
    def updateConfSections(self):
      sections=['wizard']
      config = self.datamodel.config
      if not('wizard' in self.datamodel.config.sections()):
        config.add_section('wizard')
      
      config['wizard']['id'] = '<xsl:value-of select="@id"/>'
      self.datamodel.registerkey('wizard', 'id')
      
      config['wizard']['version'] = '<xsl:value-of select="info/version"/>'
      self.datamodel.registerkey('wizard', 'version')
      
      for pageid in self.pageSteps:
        sectionname = self.page(pageid).sectionName
        if sectionname:
          sections.append(sectionname)
        
      self.datamodel.allowedSections = sections
      if _debug:
        print ('Sections allowed:')
        print (self.datamodel.allowedSections)
      
    def writeConf(self):
      self.datamodel.writeConf(self.allFieldNames())
      
    def sessionNameAlreadyUsed(self):
      return self.datamodel.sessionNameAlreadyUsed()
      
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
    
    def nextId(self):
      return self.wizard().nextId()

    def setVariables(self):
      pass
      
    def requires(self):
      return []      
      
    def readData(self, config, datamodel):
      pass
      
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
        self.treeApplications.setItemDelegate(CRadioButtonDelegate())
        self.treeApplications.setSelectionMode(QtWidgets.QAbstractItemView.MultiSelection)
        layout.addWidget(self.treeApplications)
        self.setLayout(layout)
        self.sectionName = None
        self.hashSteps = {}

        self.wizard()

        
    def initializePage(self):
        self.setTitle('<xsl:value-of select='first-page/title'/>')
        self.labelDescription.setText('<xsl:apply-templates select='first-page/description' mode="description"/>')
        if self.wizard().startguioption:
          self.checkStartgui.setText('Check if you want to start GUI once the Session document has been created')
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
          print("wizard.sectionnames property not found or not well formed")
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
          group.setToolTip(0,"[optional] <xsl:value-of select="../title"/>")
          group.setToolTip(1,"[optional] <xsl:value-of select="../title"/>")
          
        child = QtWidgets.QTreeWidgetItem(group)
        child.setFlags(QtCore.Qt.ItemIsUserCheckable | QtCore.Qt.ItemIsSelectable | QtCore.Qt.ItemIsEnabled)
        child.setText(0, "<xsl:value-of select="short-title"/>")
        child.setText(1, "<xsl:value-of select="@section-name"/>")
        child.setToolTip(0,"[<xsl:value-of select="@use"/>] <xsl:value-of select="title"/>")
        child.setToolTip(1,"[<xsl:value-of select="@use"/>] <xsl:value-of select="title"/>")
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
        parent.setToolTip(0,"[<xsl:value-of select="@use"/>] <xsl:value-of select="title"/>")
        parent.setToolTip(1,"[<xsl:value-of select="@use"/>] <xsl:value-of select="title"/>")
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
          if _debug:
            print ("startgui:" + str(self.wizard().startgui))
        
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
        if _debug:
          print("Selected pages:")
        self.wizard().stepindex = 0
        self.wizard().printPageSteps()
        return True

<xsl:for-each select='//page'>

class <xsl:value-of select='@id'/>Page(BasePage):
    def __init__(self, parent=None):
        super(<xsl:value-of select='@id'/>Page, self).__init__(parent)
        self.sectionName = '<xsl:value-of select='@section-name'/>'
        datamodel = None
        headers = []
        fields = []
        <xsl:apply-templates mode="__init__create_instance"/>
        
        # we free widgets
        fields = []
        headers = []
        layout = QtWidgets.QVBoxLayout(self)
        <xsl:apply-templates mode="__init__add_to_layout"/>

<!--        layout = QtWidgets.QVBoxLayout()
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
        <xsl:when test='@type = "TableWidgetWithComboBox"'>
        layout.addWidget(self._<xsl:value-of select='@id'/>)
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
-->      

    def readData(self, config, datamodel):
          if _debug:
            print('[====== readData')
          <xsl:apply-templates mode="initializePage_readdata"/>    
          if _debug:
            print(']====== readData')
        
    def initializePage(self):
        if _debug:
          print ("[==== initializePage " + self.sectionName)

        datamodel = self.wizard().datamodel
        data = datamodel.data
        config = datamodel.config
        
        <xsl:apply-templates mode="initializePage_initialize"/>
        if self.sectionName in config.sections():
          self.readData(config, datamodel)
        else:
          self.defaults()

        self.setTitle('<xsl:value-of select='title'/>')
        <xsl:for-each select='field'>
        self._label_<xsl:value-of select='@id'/>.setText('<xsl:value-of select='label'/>')
        </xsl:for-each>
        <xsl:for-each select='group'>
        self._label_<xsl:value-of select='@id'/>.setText('<xsl:value-of select='label'/>')
        </xsl:for-each>
        if _debug:
          print ("]==== initializePage " + self.sectionName)

    def validatePage(self):
        if _debug:
          print ("[==== validatePage " + self.sectionName)
        
        config = self.wizard().datamodel.config
        datamodel = self.wizard().datamodel
        
        if <xsl:for-each select="field"><xsl:if test="line-edit"> self._<xsl:value-of select='@id'/>.hasAcceptableInput() and</xsl:if></xsl:for-each><xsl:for-each select="group"> self._<xsl:value-of select='@id'/>.hasAcceptableInput() and</xsl:for-each> True:
        
          <xsl:apply-templates mode="validatePage"/>
          
          if _debug:
            datamodel.printConf()
          if _debug:
            pprint.pprint(datamodel.data)
          return True
        else:
          return False
        if _debug:
          print ("]==== validatePage " + self.sectionName)
        
    def defaults(self):
        if _debug:
          print ("Apply defaults")
        
        config = self.wizard().datamodel.config
        if self.sectionName not in config.sections():
          config.add_section(self.sectionName)
          
        <xsl:apply-templates mode="defaults"/>
        
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
      self.labelDescription.setText('<xsl:apply-templates select='last-page/description' mode="description"/>')
      
      str_conf = self.wizard().cleanConfAsString()  
      self.textEdit.setPlainText(str_conf)
      self.textEdit.setReadOnly(True)
      
    def validatePage(self):
      
      datamodel = self.wizard().datamodel
      if not (datamodel.sessionNameAlreadyUsed()):
        QtWidgets.QApplication.setOverrideCursor(QtGui.QCursor(QtCore.Qt.WaitCursor))
        self.wizard().writeConf()
        
        tmpdir = tempfile.mkdtemp()      
        outdir = datamodel.session_path
        if self.wizard().jsonfilename == None:
          tmp = tempfile.NamedTemporaryFile()
          datamodelfile=tmp.name
        else:
          datamodelfile = self.wizard().jsonfilename
        
        conffile = datamodel.configfilename
        self.wizard().writeJSON(datamodelfile)
          
        templatedir = os.path.abspath(os.path.dirname(__file__))
        if _debug:
          print ('sys.path' + str(sys.path))
          print ('-- conf file:' + str(conffile) + '\n-- datamodel file:' + str(datamodelfile) + '\n-- rayZtemplatedir:' + str(templatedir) + '\n-- tmp dir:' + str(tmpdir) + '\n-- startgui:' + str(self.wizard().startgui) + "\n-- session_manager:" + self.wizard().session_manager)
        
        from tmpl_wizard import SessionTemplate
        try:
          SessionTemplate().fillInTemplate(datamodelfile, templatedir, tmpdir, startgui=self.wizard().startgui, session_manager=self.wizard().session_manager, conffile=conffile, debug=_debug)
          QtWidgets.QApplication.restoreOverrideCursor()
          QtWidgets.QMessageBox.information(self,
                                            "Session creation ...",
                                            "The Session has been successfully created.")
          return True
        except Exception as exception:
          traceback.print_exc()
          print("Exception: {}".format(type(exception).__name__))
          print("Exception message: {}".format(exception))          
          QtWidgets.QApplication.restoreOverrideCursor()
          QtWidgets.QMessageBox.critical(self,
                                            "Session creation ...",
                                            "An error occured during the creation process (see logs for more details)")
          return False
      else:
        QtWidgets.QMessageBox.critical(self,
                                            "Session creation ...",
                                            "The Session already exists ! '" + self.wizard().datamodel.session_path + "'&lt;br/&gt;Please try another name.")
      return False

      
def usage():
  print ("Usage:")
  print ("wizard.py [options)")
  print ("   -h|--help              : print this help text")
  print ("   -d                     : debug information")
  print ("   -c|--conf-file         : set the conf filename to read/write")
  print ("   -j|--write-json-file   : set the JSON file to write. It is used to fill the template and contains user inputs and wizard outputs variables.")
  print ("   -s|--start-gui-option  : the wizard will display an option for starting raysession software at the end of the document creation.")
  print ("   -m|--session-manager   : set the session-manager of the resulting document")
  print ("                             - ray_control : (default) create a raysession document. You will need raysession software for the processing,")
  print ("                             - nsm         : create a nsm session. You wont need non-session-manager for the document generation,")
  
if __name__ == '__main__':
  jsonfilename = None
  startguioption = False
  session_manager = 'ray_control'
  conffile = "<xsl:value-of select="@id"/>.conf"
  import sys
  try:                                
    opts, args = getopt.getopt(sys.argv[1:], "hc:j:dsm:", ["help", "conf-file=", "write-json-file=","debug","start-gui-option","session-manager="])
    print ("args list: ")
    print(opts)
  except getopt.GetoptError:          
    usage()                         
    sys.exit(2)                     
  for opt, arg in opts:
    if opt in ("-h", "--help"):
      usage()                     
      sys.exit()                  
    elif opt in ('-c', '--conf-file'):
      conffile = arg
      print ('read/write conf file %s' % conffile)
    elif opt in ('-d', "--debug"):
      _debug = True               
    elif opt in ("-j", "--write-json-file"):
      jsonfilename = arg
      print ("will write a json file '%s' when finishing the wizard steps." % jsonfilename)
    elif opt in ("-s", "--start-gui-option"):
      startguioption=True
    elif opt in ("-m", "--session-manager"):
      session_manager=arg
      if session_manager not in ['ray_control', 'nsm']:  
        print ('--session-manager options : "ray_control|nsm"')
        sys.exit(2)
  
  print ('[==== wizard')
  app = QtWidgets.QApplication(sys.argv)
  wizard = SessionWizard(jsonfilename=jsonfilename, startguioption=startguioption, session_manager=session_manager, configfilename=conffile)
  layout = [QtWidgets.QWizard.CustomButton1, QtWidgets.QWizard.CustomButton2, QtWidgets.QWizard.BackButton, QtWidgets.QWizard.CancelButton, QtWidgets.QWizard.NextButton, QtWidgets.QWizard.FinishButton]
  wizard.setButtonLayout(layout);    
  wizard.setButtonText(QtWidgets.QWizard.CustomButton1, "Defaults")
  wizard.setButtonText(QtWidgets.QWizard.CustomButton2, "Read conf")
  wizard.show()
  wizard.button(QtWidgets.QWizard.CustomButton1).clicked.connect(wizard.defaults)
  wizard.button(QtWidgets.QWizard.CustomButton2).clicked.connect(wizard.readData)
  
  exitcode = app.exec_()
  print (']==== wizard')
  sys.exit(exitcode)

</xsl:template>

<!-- 

defaults RULES

-->
<!-- Ignore those tags -->
<xsl:template match='title|short-title|requires|template-snippet|template' mode="defaults"/>

<xsl:template match="group" mode="defaults">
        self._<xsl:value-of select='@id'/>.defaults()
</xsl:template>

<xsl:template match="field" mode="defaults">
        self._<xsl:value-of select='@id'/>.defaults()
</xsl:template>


<!-- 

validatePage RULES

-->

<!-- Ignore those tags -->
<xsl:template match='title|short-title|requires|template-snippet|template' mode="validatePage"/>

<xsl:template match="field" mode="validatePage">
  <xsl:choose>
    <xsl:when test="line-edit">
          self._<xsl:value-of select='@id'/>.updateData(config, datamodel)
    </xsl:when>
    <xsl:when test="checkbox">
          self._<xsl:value-of select='@id'/>.updateData(config, datamodel)
    </xsl:when>
    <xsl:when test="combobox">
          self._<xsl:value-of select='@id'/>.updateData(config, datamodel)
    </xsl:when>
    <xsl:when test="listbox">
          self._<xsl:value-of select='@id'/>.updateData(config, datamodel)
    </xsl:when>
    <xsl:when test="list-of-combobox">
          self._<xsl:value-of select='@id'/>.updateData(config, datamodel)
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="group" mode="validatePage">
          self._<xsl:value-of select='@id'/>.updateData(config, datamodel)
</xsl:template>

<!-- 

initializePage RULES

-->

<!-- Ignore those tags -->
<xsl:template match='title|short-title|requires|template-snippet|template' mode="initializePage_readdata"/>

<xsl:template match="field" mode="initializePage_readdata">
  <xsl:choose>
    <xsl:when test="line-edit">
          self._<xsl:value-of select='@id'/>.readData(config, datamodel)
    </xsl:when>
    <xsl:when test="checkbox">
          self._<xsl:value-of select='@id'/>.readData(config, datamodel)
    </xsl:when>
    <xsl:when test="combobox">
          self._<xsl:value-of select='@id'/>.readData(config, datamodel)
    </xsl:when>
    <xsl:when test="listbox">
          self._<xsl:value-of select='@id'/>.readData(config, datamodel)
    </xsl:when>
    <xsl:when test="list-of-combobox">
          self._<xsl:value-of select='@id'/>.readData(config, datamodel)
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="group" mode="initializePage_readdata">
          self._<xsl:value-of select='@id'/>.readData(config, datamodel)
</xsl:template>

<xsl:template match='title|short-title|requires|template-snippet|template' mode="initializePage_initialize"/>

<xsl:template match="field" mode="initializePage_initialize">
        <xsl:if test="line-edit">
        self._<xsl:value-of select='@id'/>.setDatamodel(datamodel)
        </xsl:if>
        <!-- self._<xsl:value-of select='@id'/>.initialize() -->
</xsl:template>

<xsl:template match="group" mode="initializePage_initialize">
        self._<xsl:value-of select='@id'/>.initialize(datamodel.data['<xsl:value-of select='@list-id'/>'])
</xsl:template>


<!-- 

__init_add_to_layout RULES

-->

<!-- Ignore those tags -->
<xsl:template match='title|short-title|requires|template-snippet|template' mode="__init__add_to_layout"/>

<xsl:template match="field" mode="__init__add_to_layout">
        layout.addWidget(self._label_<xsl:value-of select='@id'/>)
        layout.addWidget(self._<xsl:value-of select='@id'/>)
</xsl:template>

<xsl:template match="group" mode="__init__add_to_layout">
        layout.addWidget(self._label_<xsl:value-of select='@id'/>)
        layout.addWidget(self._<xsl:value-of select='@id'/>)
</xsl:template>



<!-- 

__init_create_instance RULES

-->
<!-- Ignore those tags -->
<xsl:template match='title|short-title|requires|template-snippet|template' mode="__init__create_instance"/>

<xsl:template match="group" mode="__init__create_instance">
        fields=[]
        headers=[]
        self._label_<xsl:value-of select='@id'/> = CLabel('<xsl:value-of select='label'/>')
        <xsl:apply-templates select="field" mode="__init__create_instance"/>
        self._<xsl:value-of select='@id'/> = CGroupOfComponentWidget(None, fields,sectionName=self.sectionName, headerlist=headers<xsl:if test="@min">,minChecked=<xsl:value-of select="@min"/></xsl:if><xsl:if test="@max">,maxChecked=<xsl:value-of select="@max"/></xsl:if>,key='<xsl:value-of select='@id'/>', display='<xsl:value-of select='@display'/>')
</xsl:template>

<xsl:template match="field" mode="__init__create_instance">
        self._label_<xsl:value-of select='@id'/> = CLabel('<xsl:value-of select='label'/>')
        headers.append(self._label_<xsl:value-of select='@id'/>)
        modelAction = None        
  <xsl:choose>
    <xsl:when test="line-edit">
        validator = None
        <xsl:apply-templates select="line-edit/*"/>
        self._<xsl:value-of select='@id'/> = CLineEdit(sectionName=self.sectionName, key='<xsl:value-of select='@id'/>', defaultvalue='<xsl:value-of select="line-edit/@default-value"/>', blankAllowed=<xsl:value-of select='line-edit/@blank-allowed'/>, message=False<xsl:if test="not (ancestor::group)">, parent=self</xsl:if>)
        self._<xsl:value-of select='@id'/>.setValidator(validator)
        self._<xsl:value-of select='@id'/>.setModelAction(modelAction)
        fields.append(self._<xsl:value-of select='@id'/>)
    </xsl:when>
    <xsl:when test="checkbox">
        self._<xsl:value-of select='@id'/> = CCheckBox('<xsl:value-of select='label'/>', defaultvalue=<xsl:value-of select='checkbox/@default-value'/>, sectionName=self.sectionName, key='<xsl:value-of select='@id'/>'<xsl:if test="not (ancestor::group)">, parent=self</xsl:if>)
        self._<xsl:value-of select='@id'/>.setModelAction(modelAction)
        fields.append(self._<xsl:value-of select='@id'/>)
    </xsl:when>
    <xsl:when test="combobox">
        roleitemlist = None
        itemlist = None
        <xsl:apply-templates select="combobox/*"/>
        self._<xsl:value-of select='@id'/> = CComboBox(itemlist=itemlist, roleitemlist=roleitemlist, defaultvalue='<xsl:value-of select='combobox/@default-value'/>', sectionName=self.sectionName, key='<xsl:value-of select='@id'/>'<xsl:if test="not (ancestor::group)">, parent=self</xsl:if>)
        self._<xsl:value-of select='@id'/>.setModelAction(modelAction)
        fields.append(self._<xsl:value-of select='@id'/>)
    </xsl:when>
    <xsl:when test="listbox">
        roleitemlist = None
        itemlist = None
        selectedlist = []
        <xsl:apply-templates select="listbox/*"/>
        self._<xsl:value-of select='@id'/> = CListWidget(itemlist=itemlist, roleitemlist=roleitemlist, selectedlist=selectedlist, selectionMode=<xsl:value-of select='listbox/@selection-mode'/>, sectionName=self.sectionName, key='<xsl:value-of select='@id'/>'<xsl:if test="not (ancestor::group)">, parent=self</xsl:if>)
        self._<xsl:value-of select='@id'/>.setModelAction(modelAction)
        fields.append(self._<xsl:value-of select='@id'/>)
    </xsl:when>
    <xsl:when test="list-of-combobox">
        roleitemlist = None
        itemlist = None
        <xsl:apply-templates select="list-of-combobox/*"/>
        self._<xsl:value-of select='@id'/> = CListOfComboBox(itemlist=itemlist, roleitemlist=roleitemlist, defaultvalue='<xsl:value-of select='list-of-combobox/@default-value'/>', sectionName=self.sectionName, key='<xsl:value-of select='@id'/>', display='<xsl:value-of select='list-of-combobox/@display'/>', seperator='<xsl:value-of select='list-of-combobox/@join'/>', count=<xsl:value-of select='list-of-combobox/@count'/>,ignoreblank=<xsl:value-of select='list-of-combobox/@ignore-blank'/><xsl:if test="not (ancestor::group)">, parent=self</xsl:if>)
        self._<xsl:value-of select='@id'/>.setModelAction(modelAction)
        fields.append(self._<xsl:value-of select='@id'/>)
    </xsl:when>
  </xsl:choose>
</xsl:template>


<xsl:template match="int-validator">
        validator = CIntValidator(<xsl:value-of select='@min'/>,<xsl:value-of select='@max'/>, parent=self)            
</xsl:template>

<xsl:template match="regexp-validator">
  <xsl:choose>
    <xsl:when test='@type = "custom"'>
        validator = CRegExpValidator('<xsl:value-of select='@regexp'/>')
    </xsl:when>
    <xsl:otherwise>
        validator = CRegExpValidator(<xsl:value-of select='@type'/>re)
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="session-name-validator">
        validator = CSessionNameValidator(datamodel, self)
</xsl:template>

<xsl:template match="model-split">
        modelAction = CSplitModelAction('<xsl:value-of select='@seperator'/>')
</xsl:template>

<xsl:template match="model-jack">
        modelAction = CJackModelAction('<xsl:value-of select='@io-type'/>', '<xsl:value-of select='@channel-type'/>')
</xsl:template>

<xsl:template match="command">
        try:
          my_env = os.environ
          my_env["PATH"] = os.path.abspath(os.path.dirname(__file__)) + os.sep + "bin:" + my_env["PATH"]
          out = subprocess.check_output(shlex.split('<xsl:value-of select="@call"/>'), env=my_env, shell=True, text=True)        
          itemlist = out.splitlines()
          selectedlist= []
          <xsl:if test="@selection-startswith">
          for i in range(len(itemlist)):
            if itemlist[i].startswith('<xsl:value-of select="@selection-startswith"/>'):
              itemlist[i] = itemlist[i][len('<xsl:value-of select="@selection-startswith"/>'):]
              selectedlist.append(i)
          </xsl:if>
        except Exception as e:
          print (e)
          print ('Could not initialize the field values for "<xsl:value-of select='@id'/>".')
    
</xsl:template>

<xsl:template match="items">
        itemlist = []
  <xsl:for-each select="item">
        itemlist.append('<xsl:value-of select='@label'/>')
  </xsl:for-each>
</xsl:template>

<xsl:template match="role-items">
        roleitemlist = []
  <xsl:for-each select="item">
        roleitemlist.append(('<xsl:value-of select='@id'/>', '<xsl:value-of select='@label'/>'))
  </xsl:for-each>
</xsl:template>

<xsl:template match="description" mode="description"><xsl:for-each select="tokenize(., '\n')[normalize-space()]"><xsl:value-of select="." />\n</xsl:for-each></xsl:template>

</xsl:stylesheet>
