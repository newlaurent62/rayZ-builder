#!/usr/bin/env python

from PyQt5 import QtCore
from PyQt5 import QtGui
from PyQt5 import QtWidgets
import re
from ui_checklineedit import CheckLineEdit

inputsregexp = "((([a-zA-Z]\w*):)?([0-9]+))(,((([a-zA-Z]\w*):)?([0-9]+)))*->(LR|L|R|)\s*"
inputsre = re.compile(inputsregexp)
outputsregexp = "(LR|L|R)->(([a-zA-Z]\w*):)?([0-9]+)(,(([a-zA-Z]\w*):)?([0-9]+))*\s*"
outputsre = re.compile(outputsregexp)
inputsQregexp = QtCore.QRegularExpression('^(' + inputsregexp + ')*$')
outputsQregexp = QtCore.QRegularExpression('^(' + outputsregexp + ')*$')


class UsersListEdit(QtWidgets.QWidget):
  def __init__(self, parent=None, sectionName=None, usercountmax=5, property_hided='user', property_checked=None,inputs=True, outputs=True):
      super(UsersListEdit, self).__init__(parent)
      
      self.usercountmax = usercountmax
      self.inputs = inputs
      self.outputs = outputs
      self.labelMessage = QtWidgets.QLabel()
      self.checkConnected = []
      self.lineEditInputs = [] 
      self.lineEditOutputs = [] 
      self.lineEditNames = []     
      self.labelUsername = QtWidgets.QLabel()
      self.labelConnected = QtWidgets.QLabel()
      self.labelInputs = QtWidgets.QLabel()
      self.labelOutputs = QtWidgets.QLabel()
      self.page = parent
      self.userindexConnected = QtWidgets.QLineEdit(self)
      self.listnamesConnected = QtWidgets.QLineEdit(self)
      self.listnames = []
      self.property_checked = property_checked
      self.property_hided = property_hided
      self.datalist = []
      if self.property_checked != None:
        parent.registerField(self.property_checked, self.userindexConnected)
        self.userindexConnected.textChanged.check(self.updateChecks)
        parent.registerField(self.property_checked.replace('-hide',''), self.listnamesConnected)

      inputsValidator = QtGui.QRegularExpressionValidator(inputsQregexp, self)
      outputsValidator = QtGui.QRegularExpressionValidator(outputsQregexp, self)
      for i in range(self.usercountmax):
        if self.property_checked != None:
          self.checkConnected.append(QtWidgets.QCheckBox(self))
        self.lineEditNames.append(QtWidgets.QLineEdit(self))
        if inputs:
          self.lineEditInputs.append(CheckLineEdit(self,message=False))
          self.lineEditInputs[i].setValidator(inputsValidator)
        if outputs:
          self.lineEditOutputs.append(CheckLineEdit(self,message=False))
          self.lineEditOutputs[i].setValidator(outputsValidator)
        
        parent.registerField(parent.sectionName + '.' + self.property_hided + str(i) + '-name-hide', self.lineEditNames[i])
        if self.property_checked:
          parent.registerField(parent.sectionName + '.bool' + self.property_hided + str(i) + '-checked-hide', self.checkConnected[i])
        if self.inputs:
          parent.registerField(parent.sectionName + '.' + self.property_hided + str(i) + '-inputs-hide', self.lineEditInputs[i].lineEdit)
        if self.outputs:
          parent.registerField(parent.sectionName + '.' + self.property_hided + str(i) + '-outputs-hide', self.lineEditOutputs[i].lineEdit)

  def updateChecks(self):
    print ('+++updatechecks+++')
    if self.property_checked != None:
      listnamesSelected = []
      indexes = self.page.field(self.property_checked)
      print (indexes)
      for i in range(self.usercountmax):
        self.checkConnected[i].show()
        if str(i) in indexes:
          listnamesSelected.append(self.lineEditNames[i].text())
          self.checkConnected[i].setChecked(True)
        else:
          self.checkConnected[i].setChecked(False)
      self.listnamesConnected.setText(','.join(listnamesSelected))
    print (self.listnamesConnected.text() + ' => ' + self.userindexConnected.text())
    
  def initialize(self, listnames):
    print ('initialize')
    self.listnames = listnames
    self.labelUsername.setText('User name')
    if self.inputs:
      self.labelInputs.show()
      self.labelInputs.setText('Inputs')
    else:
      self.labelInputs.hide()

    if self.outputs:
      self.labelOutputs.show()
      self.labelOutputs.setText('Outputs')
    else:
      self.labelOutputs.hide()
    
    self.userindexConnected.hide()
    self.listnamesConnected.hide()
    
    for i in range(self.usercountmax):
      if i < len(self.listnames):
        name = self.listnames[i]
        if self.inputs:
          self.lineEditInputs[i].show()
        if self.outputs:
          self.lineEditOutputs[i].show()
        self.lineEditNames[i].setText(name)
        self.lineEditNames[i].show()
        self.lineEditNames[i].setEnabled(False)
        if self.property_checked:
          self.checkConnected[i].show()
      else:        
        if self.property_checked:
          self.checkConnected[i].hide()          
          self.checkConnected[i].setChecked(False)
        if self.inputs:
          self.lineEditInputs[i].setText('')
          self.lineEditInputs[i].hide()
        if self.outputs:
          self.lineEditOutputs[i].setText('')        
          self.lineEditOutputs[i].hide()
        
        self.lineEditNames[i].setText('')
        self.lineEditNames[i].hide()
      
  def hasAcceptableInput(self):
    if self.check():
      for i in range(len(self.listnames)):
        if self.inputs and not self.lineEditInputs[i].hasAcceptableInput():
          return False
        if self.outputs and not self.lineEditOutputs[i].hasAcceptableInput():
          return False
      return True
    else:
      return False
    
  def check(self):        
    self.labelMessage.setText('')
    if self.inputs:
      for i in range(len(self.listnames), self.usercountmax):
        self.lineEditInputs[i].setText('')

    if self.outputs:
      for i in range(len(self.listnames), self.usercountmax):
        self.lineEditOutputs[i].setText('')

    if self.property_checked:
      userschecked = []
      for i in range(len(self.listnames)):
        if self.checkConnected[i].isChecked():
          userschecked.append(str(i))
      self.userindexConnected.setText(','.join(userschecked))
            
    if self.inputs:
      for i in range(len(self.listnames)):
        if self.lineEditInputs[i].text() != '':
          for j in range(len(self.listnames)):
            if i != j:
              if self.lineEditInputs[i].text() != '' and self.lineEditInputs[i].text() == self.lineEditInputs[j].text():
                self.labelMessage.setText('<span style="color:red">Inputs must be different for each user ! (You can leave blank if no checkions is needed) </span>')
                return False

    if self.outputs:
      for i in range(len(self.listnames)):
        if self.lineEditOutputs[i].text() != '':
          for j in range(len(self.listnames)):
            if i != j:
              if self.lineEditOutputs[i].text() != '' and self.lineEditOutputs[i].text() == self.lineEditOutputs[j].text():
                self.labelMessage.setText('<span style="color:red">Outputs must be different for each user ! (You can leave blank if no checkions is needed) </span>')
                return False
              
    return True
      
  def addToLayout(self, layout):
    layout.addWidget(self.labelMessage)
    #layout.addWidget(self.listnamesConnected)
    
    grid_layout = QtWidgets.QGridLayout()
    if self.property_checked != None:
      grid_layout.addWidget(self.labelConnected,0,0)
    grid_layout.addWidget(self.labelUsername,0,1)
    if self.inputs:
      grid_layout.addWidget(self.labelInputs,0,3)
    if self.outputs:
      grid_layout.addWidget(self.labelOutputs,0,5)

    for i in range(self.usercountmax):
      if self.property_checked != None:
        grid_layout.addWidget(self.checkConnected[i],i+1,0)
      grid_layout.addWidget(self.lineEditNames[i],i+1,1)
      if self.inputs:
        self.lineEditInputs[i].addWidgetsTo(grid_layout,i+1,3)
      if self.outputs:
        self.lineEditOutputs[i].addWidgetsTo(grid_layout,i+1,5)
    
    layout.addLayout(grid_layout)
 

  def readConf(self, config):
    print('Reading ' + self.property_hided + '...')
    sectionName = self.page.sectionName
    
    listnames = self.listnames
    listnamesidx = {}
    for i in range(len(listnames)):
      listnamesidx[listnames[i]] = str(i)
    
    if self.property_checked:
      property_checked_values = config[sectionName][property_checked].split(',')
      property_checked_idx = []
      for name in property_checked_values:
        property_checked_idx.append(listnamesidx[name])
      config[sectionName][property_checked + '-hide'] = ','.join(property_checked_idx)
      self.page.setField(sectionName + '.' + property_checked + '-hide', ','.join(property_checked_idx))
  
    for i in range(len(listnames)):
      name = listnames[i]
      if self.property_checked and rname in property_checked_values:
        self.page.setField(sectionName + '.bool' + self.property_hided + str(i) + '-checked-hide', True)
      self.page.setField(sectionName + '.' + self.property_hided + str(i) + '-name-hide', name)
      if self.inputs:
        try:
          self.page.setField(sectionName +'.' + self.property_hided + str(i) + '-inputs-hide', config[sectionName]['user.' + name + '.inputs'])
        except:
          self.page.setField(sectionName + '.' + self.property_hided + str(i) + '-inputs-hide', '')

      if self.outputs:
        try:
          self.page.setField(sectionName + '.' + self.property_hided + str(i) + '-outputs-hide', config[sectionName]['user.' + name + '.outputs'])
        except:
          self.page.setField(sectionName + '.' + self.property_hided + str(i) + '-outputs-hide', '')
 
  def updateConf(self, config, datamodel_listid):
    print('Updating ' + self.property_hided + '...')
    sectionName = self.page.sectionName
    datamodel = self.page.wizard().datamodel
    datamodel.removeRegisteredKey(sectionName, self.property_hided + '.')
    listnames = self.listnames
    property_checked_idx = ''
    self.datalist = []
    if self.inputs:
      if not ('alsa_in_devices' in datamodel.data):
        datamodel.data['alsa_in_devices'] = []
  
    if self.outputs:
      if not ('alsa_out_devices' in datamodel.data):
        datamodel.data['alsa_out_devices'] = []
    
    datamodel.data[datamodel_listid + ".alsa_in_devices"] = []
    datamodel.data[datamodel_listid + ".alsa_out_devices"] = []
    for i in range(len(listnames)):
      name = listnames[i]
      element = {}
      self.datalist.append(element)
      element['name'] = name
      if self.property_checked and self.field(sectionName + '.' + property_hided + str(i) + '-checked-hide') == True:
        property_checked_idx += str(i)
      if self.inputs:
        if config[sectionName][self.property_hided  + str(i) + '-inputs-hide'] != '':
          value = self.page.field(sectionName + '.'+ self.property_hided  + str(i) + '-inputs-hide')
          config[sectionName][self.property_hided  + '.' + name + '.inputs'] = value
          datamodel.registerkey(sectionName, self.property_hided  + '.' + name + '.inputs')
          if not ('jack_connections' in element):
            element['jack_connections'] = {}
          element['jack_connections']['left_inputs'] = datamodel.leftInputs(value) 
          element['jack_connections']['right_inputs']= datamodel.rightInputs(value)
          for dev in datamodel.alsa_in_devices(value):
            if not (dev in datamodel.data[datamodel_listid + ".alsa_in_devices"]):
              datamodel.data[datamodel_listid + ".alsa_in_devices"].append(dev) 
            if not (dev in datamodel.data["alsa_in_devices"]):
              datamodel.data["alsa_in_devices"].append(dev) 
      
      if self.outputs:
        if config[sectionName][self.property_hided + str(i) + '-outputs-hide'] != '':
          value = self.page.field(sectionName + '.' + self.property_hided   + str(i) + '-outputs-hide')
          config[sectionName][self.property_hided  + '.' + name + '.outputs'] = value
          datamodel.registerkey(sectionName, self.property_hided  + '.' + name + '.outputs')
          if not ('jack_connections' in element):
            element['jack_connections'] = {}
          element['jack_connections']['left_outputs'] = datamodel.leftOutputs(value)
          element['jack_connections']['right_outputs'] = datamodel.rightOutputs(value)
          for dev in datamodel.alsa_out_devices(value):
            if not (dev in datamodel.data[datamodel_listid + ".alsa_out_devices"]):
              datamodel.data[datamodel_listid + ".alsa_out_devices"].append(dev) 
            if not (dev in datamodel.data["alsa_out_devices"]):
              datamodel.data["alsa_out_devices"].append(dev) 

    if self.property_checked:
      config[sectionName][self.property_checked] = property_checked_idx
      
    datamodel.data[datamodel_listid] = self.datalist
    
