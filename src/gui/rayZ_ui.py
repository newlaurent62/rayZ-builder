#!/usr/bin/env python

import re

from PyQt5 import Qt
from PyQt5 import QtCore
from PyQt5 import QtGui
from PyQt5 import QtWidgets

#
# Generic copyUI method to copy object
#
class copyUI:
  
  def copyUI(self, parent=None):
    pass
  
class UI(copyUI):
  modelaction = None
  sectionname = None
  
  
  def sectionName(self):
    return self.sectionname
  
  def setSectionName(self, sectionName):
    self.sectionname = sectionName
  
  def modelAction(self):
    return self.modelaction
  
  def setDatamodel(self, datamodel):
    pass
  
  def setModelAction(self, modelAction):
    self.modelaction = modelAction
  
  def readData(self, config, datamodel, prefix=''):
    pass

  def updateData(self, config, datamodel, prefix=''):
    pass
  
  def transform(self, config, datamodel, key):
    if self.modelaction:
      sectionname = self.sectionName()
      self.modelaction.transform(config, datamodel, sectionname, key)
#
# Custom Validators that implements UI
#

class CValidator(QtGui.QValidator, copyUI):
  
  model = None
  
  def datamodel(self):
    return self.model
  
  def setDatamodel(self, datamodel):
    self.model = datamodel

class CIntValidator(QtGui.QIntValidator, CValidator):
  def __init__(self, min, max, parent=None):
    super(CIntValidator, self).__init__(min, max, parent)
    self.min = min 
    self.max = max
  
  def copyUI(self, parent=None):
    return CIntValidator(self.min,self.max, parent)

class CRegExpValidator(QtGui.QRegExpValidator, CValidator):
  def __init__(self, regexp, parent=None):
    super(CRegExpValidator, self).__init__(QtCore.QRegExp(regexp), parent)
    self.regexp = regexp
  
  def copyUI(self, parent=None):
    return CRegExpValidator(self.regexp, parent)

class CSessionNameValidator(CValidator):
  def __init__(self, datamodel, parent = None):
    QtGui.QValidator.__init__(self, parent)
    self.setDatamodel(datamodel)
    
  def validate(self, inputStr, pos):
    datamodel = self.datamodel()
    if not datamodel.isSessionNameAlreadyUsed(inputStr):
      return (QtGui.QValidator.Acceptable, inputStr, pos)
    else:
      return (QtGui.QValidator.Invalid, inputStr, pos)

  def copyUI(self, parent=None):
    return SessionNameValidator(self.datamodel(), parent)

# 
# ModelAction classes
#
class CModelAction(copyUI):
  
  def transform(self, config, datamodel, sectionName, key):
    pass

class CSplitModelAction(CModelAction):
  
  def __init__(self, seperator, parent=None):
    self.seperator = seperator
    self.parent = parent
    
  def transform(self, config, datamodel, sectionName, key):
    datamodel.data[sectionName + '.' +  key + 'list'] = config[sectionName][key].split(self.seperator)


  def copyUI(self, parent=None):
    return SplitModel(self.seperator, parent)
  
class CJackModelAction(CModelAction):

  inputsregexp = "((([a-zA-Z]\w*):)?([0-9]+))(,((([a-zA-Z]\w*):)?([0-9]+)))*->(LR|L|R|)\s*"
  inputsre = re.compile(inputsregexp)
  outputsregexp = "(LR|L|R)->(([a-zA-Z]\w*):)?([0-9]+)(,(([a-zA-Z]\w*):)?([0-9]+))*\s*"
  outputsre = re.compile(outputsregexp)

  def __init__(self, iotype, channeltype, parent=None):
    self.iotype = iotype
    self.channeltype = channeltype
    self.parent = parent

  def transform(self, config, datamodel, sectionName, key):
    value = config[sectionName][key]
    if self.iotype == 'input':
      if self.channeltype == 'mono':
        datamodel.data[sectionName + '.' + key + '.inlist'] = self.leftJackInputs(value)
      if self.channeltype == 'stereo':
        datamodel.data[sectionName + '.' + key + '.inLlist'] = self.leftJackInputs(value)
        datamodel.data[sectionName + '.' + key + '.inRlist'] = self.rightJackInputs(value)
      if 'sound.alsainlist' not in datamodel.data:
        datamodel.data['sound.alsainlist'] = []
      datamodel.data['sound.alsainlist'] += self.alsa_in_devices(value)
    elif self.iotype == 'output':
      if self.channeltype == 'mono':
        datamodel.data[sectionName + '.' + key + '.outlist'] = self.leftJackOutputs(value)
      if self.channeltype == 'stereo':
        datamodel.data[sectionName + '.' + key + '.outLlist'] = self.leftJackOutputs(value)
        datamodel.data[sectionName + '.' + key + '.outRlist'] = self.rightJackOutputs(value)
      if 'sound.alsaoutlist' not in datamodel.data:
        datamodel.data['sound.alsaoutlist'] = []
      datamodel.data['sound.alsaoutlist'] += self.alsa_out_devices(value)
    else:
      raise Exception('jacktype unknown ! "%s"' % self.iotype)

  def alsa_in_devices(self,ins):
    devices=[]
    for m in self.inputsre.finditer(ins):
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
    for m in self.outputsre.finditer(outs):
      for i in range(len (m.groups())+1):
        match = m.group(i)
        if match != None:             
          if len(match) > 0 and not (':' in match) and not (',' in match) and not ('->' in match) and not match.isdigit() and not (match in ['L','R','LR']):
            device = match
            if not (device in devices):
              devices.append(device)

    return devices

  def jackInputs(self,content, inputtype='LR'):
    result=[]
    devices=[]
    for m in self.inputsre.finditer(content):
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

  def jackOutputs(self,content, inputtype='LR'):
    result=[]
    for m in self.outputsre.finditer(content):
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
    return self.jackInputs(content, inputtype='L')

  def rightJackInputs(self, content):
    return self.jackInputs(content, inputtype='R')
    
  def leftJackOutputs(self, content):
    return self.jackOutputs(content, inputtype='L')
  
  def rightJackOutputs(self, content):
    return self.jackOutputs(content, inputtype='R')

  def copyUI(self, parent=None):
    return CJackModelAction(self.iotype, self.channeltype, parent)
  
#
# Custom widget that implements UI interface
#
class CLabel(QtWidgets.QLabel, copyUI):
  def __init__(self, text, parent=None):
    super(CLabel, self).__init__(text, parent)

  def copyUI(self, parent=None):
    return CLabel(self.text(), parent=parent)

class CCheckBox(QtWidgets.QCheckBox, UI):
  def __init__(self, text, minChecked=0, defaultvalue=None, sectionName=None, key=None,maxChecked=None, parent=None):
    super(CCheckBox, self).__init__(text, parent)
    self.minChecked = minChecked 
    self.maxChecked = maxChecked
    self.defaultvalue = defaultvalue
    self.setSectionName(sectionName)
    self.key = key

  def copyUI(self, parent=None):
    component = CCheckBox(self.text(), sectionName=self.sectionName()(), key=self.key, minChecked=self.minChecked, maxChecked=self.maxChecked, parent=parent)
    modelaction = self.modelAction()
    if modelaction:
      component.setModelAction(modelaction.copyUI(parent=combo))
    return component
  
  def readData(self, config, datamodel, keyprefix=''):
    key = keyprefix + '.' + self.key
    if keyprefix == '':
      key = self.key
    value = config[self.sectionName()][key] 
    if value and value.lower() == 'true':
      self.setCheckState(QtCore.Qt.Checked)
    
  def updateData(self, config, datamodel, keyprefix=''):
    key = keyprefix + '.' + self.key
    if keyprefix == '':
      key = self.key
    datamodel.registerkey(self.sectionName(), key)
    config[self.sectionName()][key] = str(self.isChecked())
    
  def defaults(self):
    print ('defaultvalue:' + str(self.defaultvalue))
    if self.defaultvalue:
      self.setCheckState(QtCore.Qt.Checked)
    else:
      self.setCheckState(QtCore.Qt.Unchecked)

  def initialize(self):
    pass

class CComboBox(QtWidgets.QComboBox, UI):
  def __init__(self, itemlist=None, roleitemlist=None, sectionName=None, key=None, defaultvalue=None, parent=None):
    super(CComboBox, self).__init__(parent)
    self.itemlist = itemlist
    self.roleitemlist = roleitemlist
    if itemlist and roleitemlist:
      raise Exception('Cannot init with itemlist and roleitemlist ! Please choose ...')
    elif itemlist:
      self.addItems(itemlist)
    elif roleitemlist:
      for (id, label) in roleitemlist:
        self.addItem(id, label)
    self.defaultvalue = defaultvalue
    self.setSectionName(sectionName)
    self.key = key

  def copyUI(self, parent=None):
    combo = ComboBox(itemlist=self.itemlist, roleitemlist=self.roleitemlist, sectionName=self.sectionName(),key=self.key, defaultvalue=self.defaultvalue, parent=parent)
    modelaction = self.modelAction()
    if modelaction:
      combo.setModelAction(modelaction.copyUI(parent=combo))
    return combo
  
  def defaults(self):
    print ('defaultvalue:' + str(self.defaultvalue))
    index = self.findText(self.defaultvalue, QtCore.Qt.MatchFixedString)
    if index >= 0:
      self.setCurrentIndex(index)

  def readData(self, config, datamodel, keyprefix=''):
    key = self.key
    if keyprefix!='':
      key = keyprefix + '.' + self.key

    if key in config[self.sectionName()]:
      index = self.findText(config[self.sectionName()][key], QtCore.Qt.MatchFixedString)
      if index >= 0:
        self.setCurrentIndex(index)
    else:
      self.lineEdit.setText('')
    
  def updateData(self, config, datamodel, keyprefix=''):
    key = self.key
    
    if keyprefix!='':
      property_name = keyprefix + '.' + self.key

    datamodel.registerkey(self.sectionName(), key)
    config[self.sectionName()][key] = self.currentText()
    
    self.transform(config, datamodel, key)
    
  def initialize(self):
    pass
    
class CListWidget(QtWidgets.QListWidget, UI):
  def __init__(self, itemlist=None, roleitemlist=None, selectedlist=None, selectionMode='multiple', parent=None):
    super(CListWidget, self).__init__(parent)
    self.itemlist = itemlist
    self.roleitemlist = roleitemlist
    if self.itemlist and self.roleitemlist:
      raise Exception('Cannot initialize itemlist and roleitemlist at same time !')
    elif self.itemlist:
      self.addItems(itemlist)
    elif self.roleitemlist:
      for (id,label) in roleitemlist:
        self.addItem(id,label)
    self.selectionMode = selectionMode
    self.selectedlist = selectedlist
    if self.selectionMode == 'multiple':
      self.setSelectionMode(QtWidgets.QAbstractView.ExtendedSelection)
      for index in selectedlist:
        self.itemAt(index).setSelected(True)
    elif self.selectionMode == 'single':
      self.itemAt(self.selectedlist[0]).setSelected(True)
    else:
      raise Exception('Unknown selection mode ! ("multiple" or "single") only')

  def copyUI(self, parent=None):
    list = ListWidget(itemlist=self.itemlist, roleitemlist=self.roleitemlist, selectedlist=self.selectedlist,selectionMode=self.selectionMode, parent=parent)
    modelaction = self.modelAction()
    if modelaction:
      list.setModelAction(modelaction.copyUI(parent=combo))
    return list
 

  def defaults(self):
    if self.selectionMode == 'multiple':
      for index in selectedlist:
        self.itemAt(index).setSelected(True)
    elif self.selectionMode == 'single':
      self.itemAt(self.selectedlist[0]).setSelected(True)    

  def readData(self, config, datamodel, keyprefix=''):
    key = self.key
    if keyprefix!='':
      key = keyprefix + '.' + self.key

    if key in config[self.sectionName()]:
      values = config[self.sectionName()][key].split(',')
      if self.selectionMode == 'multiple':
        for value in values:
          index = self.findText(value, QtCore.Qt.MatchFixedString)
          if index >= 0:
            self.setCurrentIndex(index)
      elif self.selectionMode == 'single':
        value = config[self.sectionName()][key]
        index = self.findText(value, QtCore.Qt.MatchFixedString)
        if index >= 0:
          self.setCurrentIndex(index)
      else:
        raise Exception('Unknown selection mode ! ("multiple" or "single") only')
    else:
      self.setCurrentIndex(0)
    
  def updateData(self, config, datamodel, keyprefix=''):
    key = self.key
    
    if keyprefix!='':
      property_name = keyprefix + '.' + self.key

    if self.selectionMode == 'multiple':
      itemlist = self.selectedItems()
      itemtextlist = []
      for item in itemlist :
        itemtextlist.append(item.text())
      config[self.sectionName()][key] = ','.join(itemtextlist)
      datamodel.data[self.sectionName() + '.' + key + 'list'] = itemtextlist
    elif self.selectionMode == 'single':
      config[self.sectionName()][key] = self.currentText()
    else:
      raise Exception('Unknown selection mode ! ("multiple" or "single") only')
    
    self.transform(config, datamodel, key)
      
    datamodel.registerkey(self.sectionName(), key)

  def initialize(self):
    pass

class CLineEdit(QtWidgets.QWidget, UI):
  def __init__(self, parent=None, defaultvalue=None, sectionName=None, key=None, message=True, inputMask=None, blankAllowed=False):
    super(CLineEdit, self).__init__(parent)
    self.message = message
    self.setSectionName(sectionName)
    self.key = key
    self.blankAllowed = blankAllowed
    self.inputMask = inputMask
    self.defaultvalue=defaultvalue
    self.lineEdit = QtWidgets.QLineEdit(self)
    if self.inputMask:
      self.lineEdit.setInputMask(self.inputMask)
    self.lineEdit.textChanged[str].connect(self.check)
    self.labelCheck = QtWidgets.QLabel()
    layout = QtWidgets.QVBoxLayout()
    if self.message:
      self.labelMessage = QtWidgets.QLabel()
      layout.addWidget(self.labelMessage)
    hlayout = QtWidgets.QHBoxLayout()
    hlayout.addWidget(self.lineEdit)
    hlayout.addWidget(self.labelCheck)
    layout.addLayout(hlayout)
    self.setLayout(layout)

  def validator(self):
    return self.lineEdit.validator()
  
  def setValidator(self, validator):
    if not isinstance(validator, CValidator):
      raise Exception('Incompatible class ! Need CValidator type ...')
    self.lineEdit.setValidator(validator)
          
  def check(self,input):
    self.setText(input)
    self.printcheck(self.hasAcceptableInput())
  
  def printcheck(self, hasAcceptableInput):
    if hasAcceptableInput:
      self.labelCheck.setText(u'\u2713')
      self.labelCheck.setStyleSheet("color: green;font-weight: bold;")

      if self.message:
        self.labelMessage.setText("")
    else:
      self.labelCheck.setText('<span style="color:red">X</span>')
      self.labelCheck.setStyleSheet("color: red;font-weight: bold;")
      if self.message:
        self.labelMessage.setText("")
  
  def setEnabled(self, bool):
    self.lineEdit.setEnabled(bool)
  
  
  def setText(self, text):
    self.lineEdit.setText(text)

  def hasAcceptableInput(self):
    if self.blankAllowed and self.text() == '':
      self.printcheck(True)
      return True
    self.printcheck(self.lineEdit.hasAcceptableInput())
    return self.lineEdit.hasAcceptableInput()
      
  def text(self):
    return self.lineEdit.text()

  def show(self):
    self.lineEdit.show()
    if self.message:
      self.labelMessage.show()
    self.labelCheck.show()
    
  def hide(self):
    self.lineEdit.hide()
    if self.message:
      self.labelMessage.hide()
    self.labelCheck.hide()

  def copyUI(self, parent):
    sectionName = super().sectionName()
    anobject = CLineEdit(parent=parent, defaultvalue=self.defaultvalue, sectionName=sectionName, key=self.key, inputMask=self.inputMask, blankAllowed=self.blankAllowed,message=self.message)
    validator = self.validator()
    if validator:
      copyOfvalidator = validator.copyUI(parent=anobject) 
      anobject.setValidator(copyOfvalidator)
    modelaction = self.modelAction()
    if modelaction:
      copyOfmodelaction = modelaction.copyUI(parent=anobject)
      anobject.setModelAction(copyOfmodelaction)
    return anobject
  
  def readData(self, config, datamodel, keyprefix=''):
    key = self.key
    if keyprefix!='':
      key = keyprefix + '.' + self.key

    if key in config[self.sectionName()]:
      self.lineEdit.setText(config[self.sectionName()][key])
    else:
      self.lineEdit.setText('')
    
  def updateData(self, config, datamodel, keyprefix=''):
    key = self.key
    
    if keyprefix!='':
      key = keyprefix + '.' + self.key

    datamodel.registerkey(self.sectionName(), key)
    config[self.sectionName()][key] = self.lineEdit.text()
    
    self.transform(config, datamodel, key)

  def setDatamodel(self, datamodel):
    super().setDatamodel(datamodel)
    validator = self.validator()
    if validator:
      validator.setDatamodel(datamodel)

  def defaults(self):
    print ('defaultvalue:' + str(self.defaultvalue))
    self.lineEdit.setText(self.defaultvalue)

  def initialize(self):
    pass


class CCheckableTabWidget(QtWidgets.QTabWidget, UI):

  def __init__(self, parent=None):
    super(CCheckableTabWidget, self).__init__(parent)    
    self.tabnamelist = []
    self.checkboxlist = []
  
  def addTab(self, widget, title):
      QtWidgets.QTabWidget.addTab(self, widget, title)
      self.tabnamelist.append(title)
      checkbox = CCheckBox('', parent=self)
      self.tabBar().setTabButton(self.tabBar().count()-1, QtWidgets.QTabBar.LeftSide, checkbox)
      self.checkboxlist.append(checkbox)
      
  def isChecked(self, index):
    if index < len(self.tabnamelist):
      return self.checkboxlist[index].checkState() == QtCore.Qt.Checked
    return None
  
  def indexOf(self, groupname):
    if self.tabnamelist:
      for i in range(len(self.tabnamelist)):
        if self.tabnamelist[i] == groupname:
          return i
    return -1
      
  def setCheckState(self, groupname, checkState):
    index = self.indexOf(groupname)
    if index != -1:
      self.checkboxlist[index].setCheckState(checkState)

  def tabnamesChecked(self):
    tabnames = []
    for i in range(self.tabBar().count()):
      if self.isChecked(i):
        tabnames.append(self.tabnamelist[i])
    return tabnames
  
class CGroupOfComponentWidget(QtWidgets.QWidget, UI):
  def __init__(self, groupnamelist, componentlist,sectionName=None, minChecked=None, maxChecked=None, headerlist=None,parent=None, key=None, display='TabH'):
    super(CGroupOfComponentWidget, self).__init__(parent)
    self.componentlist = componentlist
    self.display = display
    self.headerlist = headerlist
    self.groupnamelist = groupnamelist
    self.setSectionName(sectionName)
    self.key = key
    self.checkcountByKey = {}
    self.componentlistDict = {}
    self.groupnamelabellist = []
    self.groupnamecheckboxlist = []
    self.minChecked = minChecked
    self.maxChecked = maxChecked
    
    layout = None
    if 'Tab' in self.display:
      layout = QtWidgets.QVBoxLayout(self)
    elif 'List' in self.display:
      layout = QtWidgets.QGridLayout(self)
    else:
      raise Exception('Unrecognized display type ! "%s"' % self.display)
    self.setLayout(layout)

  def isCheckable(self):
    return 'Check' in self.display
  
  def isChecked(self, groupname):
    if 'Check' in self.display:
      if 'Tab' in self.display:
        return groupname in self.tabs.tabnamesChecked()
      elif 'List' in self.display:
        for checkbox in self.groupnamecheckboxlist:
          if checkbox.isChecked() and checkbox.text() == groupname:
            return True
        return False
    return True
  
  def setCheckState(self, groupname, state):
    if 'Check' in self.display:
      if 'Tab' in self.display:
        self.tabs.setCheckState(groupname, state)
      elif 'List' in self.display:
        for checkbox in self.groupnamecheckboxlist:
          if checkbox.text() == groupname:
            checkbox.setCheckState(state)
    
  def groupnameCheckedlist(self):
    if 'Check' in self.display:
      if 'Tab' in self.display:
        return self.tabs.tabnamesChecked()
      elif 'List' in self.display:
        result = []
        for checkbox in self.groupnamecheckboxlist:
          if checkbox.isChecked():
            result.append(checkbox.text())
        return result
      else:
        raise Exception('Cannot find the group type in the display property! ("Tab" or "List")! "%s"' % self.display)
  
    raise Exception('This group is not checkable ! "%s"' % self.display)
  
  def initialize(self, groupnamelist):      
    self.groupnamelist = groupnamelist
    self.checkcountByKey = {}
    self.componentlistDict = {}
    self.groupnamelabellist = []
    self.groupnamecheckboxlist = []    
    if 'Tab' in self.display:
      self.initializeTab(groupnamelist)
    elif 'List' in self.display:
      self.initializeList(groupnamelist)
      
  def initializeList(self, groupnamelist):
    gridlayout = self.layout()
    clearLayout(gridlayout)

    #init layout and header if Horizontal display
    currentrow = 0
    if self.display.endswith('H') and self.headerlist:
      for i in range(len(self.headerlist)):
        gridlayout.addWidget(self.headerlist[i], 0, i+1, alignment=QtCore.Qt.AlignHCenter)
        gridlayout.setRowStretch(currentrow, 0);
      self.__addline(gridlayout,currentrow+1, len(self.headerlist)+1)
      gridlayout.setRowStretch(currentrow+1,0);
      currentrow+=2
          
    self.componentlistDict = {}
    self.groupnamelabellist = []
    self.groupnamecheckboxlist = []
    for j in range(len(groupnamelist)):        
      mylist = []
      if self.display.endswith('H'):
        groupname=groupnamelist[j]
        # if list is checkable we add a checkbox rather than a label
        if 'Check' in self.display:
          checkbox = CCheckBox(groupname)
          checkbox.setStyleSheet("color: black; font-size: large;font-weight: bold;")
          self.groupnamecheckboxlist.append(checkbox)
          gridlayout.addWidget(checkbox, currentrow, 0)
        else:
          label =  CLabel(groupname)
          label.setStyleSheet("color: black; font-size: large;font-weight: bold;")
          self.groupnamelabellist.append(label)
          gridlayout.addWidget(label, currentrow, 0)
      else:
        if 'Check' in self.display:
          checkbox = CCheckBox(groupnamelist[j])
          checkbox.setStyleSheet("color: black; font-size: large;font-weight: bold;")
          self.groupnamecheckboxlist.append(checkbox)
          gridlayout.addWidget(checkbox, currentrow, 0)
        else:
          label =  CLabel(groupnamelist[j])
          label.setStyleSheet("color: black; font-size: large;font-weight: bold;")
          self.groupnamelabellist.append(label)
          gridlayout.addWidget(label, currentrow, 0)
        currentrow +=1
      for i in range(len(self.componentlist)):
        component = self.componentlist[i].copyUI(parent=self)
        if self.display.endswith('H'):
          gridlayout.addWidget(component, currentrow, i+1)
        else:
          gridlayout.addWidget(self.headerlist[i], currentrow, 0)
          currentrow += 1
          gridlayout.addWidget(component, currentrow, 0)
          gridlayout.setRowStretch(currentrow,0);
          currentrow += 1
        mylist.append(component)
      self.componentlistDict[groupnamelist[j]] = mylist
      if self.display.endswith('H'):
        self.__addline(gridlayout,currentrow+1, len(self.headerlist)+1)
        gridlayout.setRowStretch(currentrow+1,0);
        currentrow+=2
      
    gridlayout.setSpacing(0);
    
  def __addline(self, gridlayout, row, colcount):
    for i in range(colcount):
      seperator = QtWidgets.QFrame()
      seperator.setFrameShape(QtWidgets.QFrame.HLine)
      seperator.setSizePolicy(QtWidgets.QSizePolicy.Minimum,QtWidgets.QSizePolicy.Expanding)
      seperator.setLineWidth(1)
      gridlayout.addWidget(seperator, row, i)
    
  def initializeTab(self, groupnamelist):
    layout = self.layout()
    clearLayout(layout)
  
    if 'Check' in self.display:
      self.tabs = CCheckableTabWidget(self)
    else:
      self.tabs = QtWidgets.QTabWidget(self)
      
    self.pages = []
    for j in range(len(groupnamelist)):
      self.pages.append(QtWidgets.QWidget())
      self.tabs.addTab(self.pages[j], groupnamelist[j])

    self.componentlistDict = {}
    for j in range(len(groupnamelist)):        
      mylist = []
      currentrow = 0
      gridlayout = QtWidgets.QGridLayout(self)
      if self.display.endswith('H') and self.headerlist:
        for i in range(len(self.headerlist)):
          gridlayout.addWidget(self.headerlist[i].copyUI(parent=self), 0, i+1)
        gridlayout.setRowStretch(currentrow, 1);
        currentrow+=1
      for i in range(len(self.componentlist)):
        component = self.componentlist[i].copyUI(parent=self)
        if self.display.endswith('H'):
          gridlayout.addWidget(component, currentrow, i+1)
        else:
          gridlayout.addWidget(self.headerlist[i].copyUI(parent=self), currentrow, 0)
          currentrow += 1
          gridlayout.addWidget(component, currentrow, 0)
          currentrow += 1
        mylist.append(component)
      self.componentlistDict[groupnamelist[j]] = mylist
      playout = self.pages[j].layout()
      if layout:
        playout.addLayout(gridlayout)
      else:
        self.pages[j].setLayout(gridlayout)
      
    layout.addWidget(self.tabs)

  def getComponentByKey(self, key):
    if key == self.key:
      return self
    else:
      for component in self.componenlist:
        if component.key == key:
          return component
    raise Exception('The component with key "%s" has not been found !' % key)

  # header and component have the same order
  def getHeaderByKey(self, key):
    if key == self.key:
      return self
    else:
      for i in range(len(self.componenlist)):
        if component[i].key == key:
          return self.headerlist[i]
    raise Exception('The component with key "%s" has not been found !' % key)
  
  def message(self, message):
    dialog = QtWidgets.QMessageBox(self)
    dialog.setIcon(QtWidgets.QMessageBox.Critical)
    dialog.setText("Input error: %s" % message)
    dialog.addButton(QtWidgets.QMessageBox.Ok)
    dialog.exec()
    
  def hasAcceptableInput(self):
    print ("[==== hasAcceptableInput")
    boolhasAcceptableInput = True
    checkcountByKey = {}
    
    if self.componentlist:
      for component in self.componentlist:
        if isinstance(component, CCheckBox):
          checkcountByKey[component.key] = 0
        
    if self.minChecked or self.maxChecked:
      checkcountByKey[self.key] = len(self.groupnameCheckedlist())

    if self.groupnamelist:
      for i in range(len(self.groupnamelist)):
        groupname = self.groupnamelist[i]
        componentlist = self.componentlistDict[groupname]
        pagehasAcceptableInput = True
        for j in range(len(componentlist)):
          component = componentlist[j]
          if isinstance(component, CCheckBox) and component.isChecked():
            checkcountByKey[component.key] += 1
          
          if isinstance(component, CLineEdit) and not component.hasAcceptableInput():
            if 'Tab' in self.display:
              self.tabs.setTabText(i, groupname + ' X Error')
            pagehasAcceptableInput = False
              
          # if list display we don't display information on each subgroup as all the information are display on a single tab
            #elif 'List' in self.display:
              #self.groupnamelabellist[i].setText(groupname + ' ' + ' X')
            #pagehasAcceptableInput = False
            
        if pagehasAcceptableInput:
          if 'Tab' in self.display:
            self.tabs.setTabText(i, groupname + ' ' + u'\u2713')
          # if list display we don't display information on each subgroup as all the information are display on a single tab
          #elif 'List' in self.display:
            #self.groupnamelabellist[i].setText(groupname + ' ' + u'\u2713')
        else:
          boolhasAcceptableInput = False
    
    if boolhasAcceptableInput:
      for key in checkcountByKey:
        print ('key %s : %d' % (key, checkcountByKey[key]))
        component = self.getComponentByKey(key)
        if component.minChecked and component.maxChecked and component.minChecked == component.maxChecked and checkcountByKey[key] != component.minChecked:
          self.message('You must select %d elements for %s' % (component.maxChecked, key))
          boolhasAcceptableInput = False
          break;
        if component.minChecked and component.maxChecked and (checkcountByKey[key] < component.minChecked or checkcountByKey[key] > component.maxChecked):
          self.message('You must select between %d and %d elements for %s' % (component.minChecked, component.maxChecked, key))
          boolhasAcceptableInput = False
          break;
        if component.minChecked and not component.maxChecked and checkcountByKey[key] < component.minChecked:
          self.message('You must select a minimum of %d elements for %s' % (component.minChecked, key))
          boolhasAcceptableInput = False
          break;
        if not component.minChecked and component.maxChecked and checkcountByKey[key] > component.maxChecked:
          self.message('You must select a maximum of %d elements for %s' % (component.maxChecked, key))
          boolhasAcceptableInput = False
          break;
    
    print ('min: %s, max: %s hasAcceptableInput: %s' % (str(self.minChecked), str(self.maxChecked), str(boolhasAcceptableInput)))
    print ("]==== hasAcceptableInput")
    return boolhasAcceptableInput
      
    
  def readData(self, config, datamodel, keyprefix=''):
    key = keyprefix + '.' + self.key
    if keyprefix == '':
      key = self.key
    
    if self.isCheckable() and key in config[self.sectionName()]:
      groupcheckedlist = config[self.sectionName()][key].split(',')
      for groupname in groupcheckedlist:
        self.setCheckState(groupname, QtCore.Qt.Checked)
        
    for groupname in self.componentlistDict:
      for component in self.componentlistDict[groupname]:
        prefix = key + '.' + groupname
        component.readData(config,datamodel, keyprefix=prefix)
    
  def updateData(self, config, datamodel, keyprefix=''):
    key = keyprefix + '.' + self.key
    if keyprefix == '':
      key = self.key

    datamodel.removeRegiteredKey(self.sectionName(), key)

    if self.isCheckable():
      config[self.sectionName()][key] = ','.join(self.groupnameCheckedlist())
      datamodel.data[self.sectionName() + '.' + key + 'list'] = self.groupnameCheckedlist()
    
    datamodel.registerkey(self.sectionName(), key)
    
    for groupname in self.componentlistDict:
      if not 'Check' in self.display or self.isChecked(groupname):
        for component in self.componentlistDict[groupname]:
          prefix = key + '.' + groupname
          component.updateData(config,datamodel, keyprefix=prefix)

  def copyUI(self, parent=None):
    return CGroupOfComponentWidget(self.componentlist, headerlist=self.headerlist,parent=parent, key=self.key, display=self.display)

  def defaults(self):
    for groupname in self.componentlistDict:
      for component in self.componentlistDict[groupname]:
        component.defaults()
      

class CListOfComboBox(QtWidgets.QWidget, UI):
  
  def __init__(self, itemlist=None, roleitemlist=None, defaultvalue=None, parent=None, sectionName=None, key=None, display='V', seperator="!", count=5,ignoreblank=True):
    super(CListOfComboBox, self).__init__(parent)
    
    self.seperator = seperator
    self.count = count
    self.setSectionName(sectionName)
    self.key = key
    self.display=display
    self.defaultvalue = defaultvalue
    self.ignoreblank = ignoreblank
    self.itemlist = itemlist
    self.roleitemlist = roleitemlist
    layout = None
    self.combolist = []
    if self.display.endswith('V'):
      layout = QtWidgets.QVBoxLayout()
    elif self.display.endswith('H'):
      layout = QtWidgets.QHBoxLayout()
    else:
      raise Exception('Cannot determine the display type, it should ends with "H" or "V"')
    
    for i in range(count):
      combobox = QtWidgets.QComboBox()
      if self.itemlist and self.roleitemlist:
        raise Exception('Cannot initialize itemlist and roleitemlist at same time !')
      elif self.itemlist:
        combobox.addItems(self.itemlist)
      elif self.roleitemlist:
        for (id,label) in self.roleitemlist:
          combobox.addItem(id,label)
      self.combolist.append(combobox)
      layout.addWidget(combobox)
      
    self.setLayout(layout)
    
  def initialize(self):
    for i in range(self.count):
      if self.display.endswith('V'):
        self.combolist[i].setCurrentIndex(0)
      elif self.display.endswith('H'):
        self.combolist[i].setCurrentIndex(0)
      else:
        raise Exception('Cannot determine the display type, it should ends with "H" or "V"')
      
  def hasAcceptableInput(self):
    return True

  def readData(self, config, datamodel, keyprefix=''):
    print('Reading ' + self.key + '...')
    
    key = self.key
    if keyprefix!='':
      key = keyprefix + '.' + self.key
    
    values = []
    if key in config[self.sectionName()]:
      values = config[self.sectionName()][key]
    
    if values:
      listOfValues =  values.split(self.seperator)
      for i in range(min(len(listOfValues),self.count)):
        if self.ignoreblank and listOfValues[i].strip() != '':
          combo = self.combolist[i]
          index = combo.findText(listOfValues[i], QtCore.Qt.MatchFixedString)
          if index >= 0:
            combo.setCurrentIndex(index)
          else:
            combo.setCurrentIndex(0)
  
  def defaults(self):
    values = self.defaultvalue
    
    if values:
      listOfValues =  values.split(self.seperator)
      for i in range(min(len(listOfValues),self.count)):
        if self.ignoreblank and listOfValues[i].strip() != '':
          combo = self.combolist[i]
          index = combo.findText(listOfValues[i], QtCore.Qt.MatchFixedString)
          if index >= 0:
            combo.setCurrentIndex(index)
          else:
            combo.setCurrentIndex(0)
    
    
  def updateData(self, config, datamodel, keyprefix=''):
    print('Updating ' + self.key + '...')
    key = self.key
    if keyprefix!='':
      key = keyprefix + '.' + self.key

    listOfValues = []
    for i in range(self.count):
      combo = self.combolist[i]
      if self.ignoreblank and combo.currentText().strip() != '':
        listOfValues.append(combo.currentText())
      else:
        listOfValues.append(combo.currentText())

    datamodel.data[self.sectionName() + '.' + key + 'list'] = listOfValues
    config[self.sectionName()][key] = self.seperator.join(listOfValues)
    
    datamodel.registerkey(self.sectionName(), key)
    self.transform(config, datamodel, key)
    
  def copyUI(self, parent):
    component = CListOfComboBox(itemlist=self.itemlist, roleitemlist=self.roleitemlist, defaultvalue=self.defaultvalue, parent=parent, sectionName=self.sectionName(), count=self.count, key=self.key, display=self.display, seperator=self.seperator, ignoreblank=self.ignoreblank)
    modelaction = self.modelAction()
    if modelaction:
      component.setModelAction(modelaction.copyUI(parent=combo))
    return component

class CRadioButtonDelegate(QtWidgets.QStyledItemDelegate):
  def paint(self, painter, option, index):
    if not index.parent().isValid():
        QtWidgets.QStyledItemDelegate.paint(self, painter, option, index)
    else:
        widget = option.widget
        style = widget.style() if widget else QtWidgets.QApplication.style()
        opt = QtWidgets.QStyleOptionButton()
        opt.rect = option.rect
        opt.text = index.data()
        opt.state |= QtWidgets.QStyle.State_On if index.data(QtCore.Qt.CheckStateRole) else QtWidgets.QStyle.State_Off
        style.drawControl(QtWidgets.QStyle.CE_RadioButton, opt, painter, widget)

  def editorEvent(self, event, model, option, index):
    value = QtWidgets.QStyledItemDelegate.editorEvent(self, event, model, option, index)
    if value:
        if event.type() == QtCore.QEvent.MouseButtonRelease:
            if index.data(QtCore.Qt.CheckStateRole) == QtCore.Qt.Checked:
                parent = index.parent()
                for i in range(model.rowCount(parent)):
                    if i != index.row():
                        ix = parent.child(i, 0)
                        model.setData(ix, QtCore.Qt.Unchecked, QtCore.Qt.CheckStateRole)

    return value

def clearLayout(layout):
  print ("<clearLayout>")
  print("-- -- input layout: "+str(layout))
  for i in reversed(range(layout.count())):
    layoutItem = layout.itemAt(i)
    if layoutItem.widget() is not None:
        widgetToRemove = layoutItem.widget()
        print("found widget: " + str(widgetToRemove))
        widgetToRemove.setParent(None)
        layout.removeWidget(widgetToRemove)
    elif layoutItem.spacerItem() is not None:
        print("found spacer: " + str(layoutItem.spacerItem()))
    else:
        layoutToRemove = layout.itemAt(i)
        print("-- found Layout: "+str(layoutToRemove))
        clearLayout(layoutToRemove)
  print ("</clearLayout>")
  
def printWidget(widget, prefix=''):
  print ("<printWidget>")
  print (str(widget))
  layout = widget.layout()  
  printLayout(layout)
  print ("</printWidget>")
  
def printLayout(layout):
  if layout:
    for i in range(layout.count()):
      layoutItem = layout.itemAt(i)
      if layoutItem.widget() is not None:
        print("found widget: " + str(layoutItem))
        printWidget(layoutItem.widget())
      elif layoutItem.spacerItem() is not None:
        print("found spacer: " + str(layoutItem.spacerItem()))
      else:
        printLayout(layoutItem)
