#!/usr/bin/env python

from PyQt5 import QtCore
from PyQt5 import QtGui
from PyQt5 import QtWidgets
import re
from ui_checklineedit import CheckLineEdit

jack_inputsregexp = "((([a-zA-Z]\w*):)?([0-9]+))(,((([a-zA-Z]\w*):)?([0-9]+)))*->(LR|L|R|)\s*"
jack_inputsre = re.compile(jack_inputsregexp)
jack_outputsregexp = "(LR|L|R)->(([a-zA-Z]\w*):)?([0-9]+)(,(([a-zA-Z]\w*):)?([0-9]+))*\s*"
jack_outputsre = re.compile(jack_outputsregexp)
jack_inputsQregexp = QtCore.QRegularExpression('^(' + jack_inputsregexp + ')*$')
jack_outputsQregexp = QtCore.QRegularExpression('^(' + jack_outputsregexp + ')*$')


class UsersListEdit(QtWidgets.QWidget):
  def __init__(self, parent=None, sectionName=None, countmax=5, minchecked=0, maxchecked=None, property_checked=None, property_name='user', jack_inputs=False, jack_outputs=False):
      super(UsersListEdit, self).__init__(parent)
      
      self.countmax = countmax
      self.jack_inputs = jack_inputs
      self.jack_outputs = jack_outputs
      self.labelMessage = QtWidgets.QLabel()
      self.checkName = []
      self.lineEditJackInputs = [] 
      self.lineEditJackOutputs = [] 
      self.lineEditName = []     
      self.labelUsername = QtWidgets.QLabel()
      self.labelChecked = QtWidgets.QLabel()
      self.labelJackInputs = QtWidgets.QLabel()
      self.labelJackOutputs = QtWidgets.QLabel()
      self.page = parent
      self.listnames = []
      self.listchecked = []
      self.property_name = property_name
      self.property_checked = property_checked
      self.datalist = []
      self.minchecked = None
      self.maxchecked = None
      if self.property_checked:
        self.minchecked = minchecked
        if maxchecked == None:
          self.maxchecked = countmax
        else:
          self.maxchecked = maxchecked

      jack_inputsValidator = QtGui.QRegularExpressionValidator(jack_inputsQregexp, self)
      jack_outputsValidator = QtGui.QRegularExpressionValidator(jack_outputsQregexp, self)
      for i in range(self.countmax):
        if self.property_checked:
          self.checkName.append(QtWidgets.QCheckBox(self))
        self.lineEditName.append(QtWidgets.QLineEdit(self))
        if jack_inputs:
          self.lineEditJackInputs.append(CheckLineEdit(self,message=False))
          self.lineEditJackInputs[i].setValidator(jack_inputsValidator)
        if jack_outputs:
          self.lineEditJackOutputs.append(CheckLineEdit(self,message=False))
          self.lineEditJackOutputs[i].setValidator(jack_outputsValidator)
        
        parent.registerField(parent.sectionName + '.' + self.property_name + str(i) + '-name-hide', self.lineEditName[i])
        if self.property_checked:
          parent.registerField(parent.sectionName + '.bool' + self.property_name + str(i) + '-checked-hide', self.checkName[i])
        if self.jack_inputs:
          parent.registerField(parent.sectionName + '.' + self.property_name + str(i) + '-jack_inputs-hide', self.lineEditJackInputs[i].lineEdit)
        if self.jack_outputs:
          parent.registerField(parent.sectionName + '.' + self.property_name + str(i) + '-jack_outputs-hide', self.lineEditJackOutputs[i].lineEdit)
    
  def initialize(self, listnames):
    print ('initialize')
    self.listnames = listnames
    if self.property_checked:
      self.labelChecked.show()
      self.labelChecked.setText('Selection')
    self.labelUsername.setText('User name')
    if self.jack_inputs:
      self.labelJackInputs.show()
      self.labelJackInputs.setText('Jack Inputs')
    else:
      self.labelJackInputs.hide()

    if self.jack_outputs:
      self.labelJackOutputs.show()
      self.labelJackOutputs.setText('Jack Outputs')
    else:
      self.labelJackOutputs.hide()
        
    for i in range(self.countmax):
      if i < len(self.listnames):
        name = self.listnames[i]
        if self.property_checked:
          self.checkName[i].show()
        if self.jack_inputs:
          self.lineEditJackInputs[i].show()
        if self.jack_outputs:
          self.lineEditJackOutputs[i].show()
        self.lineEditName[i].setText(name)
        self.lineEditName[i].show()
        self.lineEditName[i].setEnabled(False)
        if self.property_checked:
          self.checkName[i].show()
      else:        
        if self.property_checked:
          self.checkName[i].hide()          
          self.checkName[i].setChecked(False)
        if self.jack_inputs:
          self.lineEditJackInputs[i].setText('')
          self.lineEditJackInputs[i].hide()
        if self.jack_outputs:
          self.lineEditJackOutputs[i].setText('')        
          self.lineEditJackOutputs[i].hide()
        
        self.lineEditName[i].setText('')
        self.lineEditName[i].hide()
      
  def hasAcceptableInput(self):
    if self.check():
      for i in range(len(self.listnames)):
        if self.jack_inputs and not self.lineEditJackInputs[i].hasAcceptableInput():
          return False
        if self.jack_outputs and not self.lineEditJackOutputs[i].hasAcceptableInput():
          return False
      return True
    else:
      return False
    
  def check(self):        
    self.labelMessage.setText('')
    if self.property_checked:
      for i in range(len(self.listnames), self.countmax):
        self.checkName[i].setChecked(False)
      
    if self.jack_inputs:
      for i in range(len(self.listnames), self.countmax):
        self.lineEditJackInputs[i].setText('')

    if self.jack_outputs:
      for i in range(len(self.listnames), self.countmax):
        self.lineEditJackOutputs[i].setText('')

    if self.property_checked:
      checked = []
      for i in range(len(self.listnames)):
        if self.checkName[i].isChecked():
          checked.append(str(i))
      print ("checked:" + str(len(checked)) + ' ' + str(self.minchecked) + ' ' + str(self.maxchecked))
      if len(checked) < self.minchecked or len(checked) > self.maxchecked:
        if self.minchecked == self.maxchecked:
          self.labelMessage.setText('<span style="color:red">You must select %d user(s)</span>' % self.minchecked)
        else:
          self.labelMessage.setText('<span style="color:red">You must select between %d and %d user(s)</span>' % (self.minchecked, self.maxchecked))
        return False
      
    #if self.jack_inputs:
      #for i in range(len(self.listnames)):
        #if self.lineEditJackInputs[i].text() != '':
          #for j in range(len(self.listnames)):
            #if i != j:
              #if self.lineEditJackInputs[i].text() != '' and self.lineEditJackInputs[i].text() == self.lineEditJackInputs[j].text():
                #self.labelMessage.setText('<span style="color:red">JackInputs must be different for each user ! (You can leave blank if no checkions is needed) </span>')
                #return False

    #if self.jack_outputs:
      #for i in range(len(self.listnames)):
        #if self.lineEditJackOutputs[i].text() != '':
          #for j in range(len(self.listnames)):
            #if i != j:
              #if self.lineEditJackOutputs[i].text() != '' and self.lineEditJackOutputs[i].text() == self.lineEditJackOutputs[j].text():
                #self.labelMessage.setText('<span style="color:red">JackOutputs must be different for each user ! (You can leave blank if no checkions is needed) </span>')
                #return False
              
    return True
      
  def addToLayout(self, layout):
    layout.addWidget(self.labelMessage)
    #layout.addWidget(self.listnamesConnected)
    
    grid_layout = QtWidgets.QGridLayout()
    if self.property_checked:
      grid_layout.addWidget(self.labelChecked,0,0)
    grid_layout.addWidget(self.labelUsername,0,1)
    if self.jack_inputs:
      grid_layout.addWidget(self.labelJackInputs,0,3)
    if self.jack_outputs:
      grid_layout.addWidget(self.labelJackOutputs,0,5)

    for i in range(self.countmax):
      if self.property_checked:
        grid_layout.addWidget(self.checkName[i],i+1,0)
      grid_layout.addWidget(self.lineEditName[i],i+1,1)
      if self.jack_inputs:
        self.lineEditJackInputs[i].addWidgetsTo(grid_layout,i+1,3)
      if self.jack_outputs:
        self.lineEditJackOutputs[i].addWidgetsTo(grid_layout,i+1,5)
    
    layout.addLayout(grid_layout)
 

  def readConf(self, config):
    print('Reading ' + self.property_name + '...')
    sectionName = self.page.sectionName
    
    listnames = self.listnames
    listnamesidx = {}
    for i in range(len(listnames)):
      listnamesidx[listnames[i]] = str(i)
    
    if self.property_checked:
      try:
        property_checked_values = config[sectionName][self.property_name + "." + self.property_checked].split(',')
      except KeyError:
        property_checked_values = []
          
    for i in range(len(listnames)):
      name = listnames[i]
      if self.property_checked and name in property_checked_values:
        self.page.setField(sectionName + '.bool' + self.property_name + str(i) + '-checked-hide', True)
      self.page.setField(sectionName + '.' + self.property_name + str(i) + '-name-hide', name)
      if self.jack_inputs:
        try:
          self.page.setField(sectionName +'.' + self.property_name + str(i) + '-jack_inputs-hide', config[sectionName]['user.' + name + '.jack_inputs'])
        except:
          self.page.setField(sectionName + '.' + self.property_name + str(i) + '-jack_inputs-hide', '')

      if self.jack_outputs:
        try:
          self.page.setField(sectionName + '.' + self.property_name + str(i) + '-jack_outputs-hide', config[sectionName]['user.' + name + '.jack_outputs'])
        except:
          self.page.setField(sectionName + '.' + self.property_name + str(i) + '-jack_outputs-hide', '')
 
  def updateConf(self, config, datamodel_listid):
    print('Updating ' + self.property_name + '...')
    sectionName = self.page.sectionName
    datamodel = self.page.wizard().datamodel
    datamodel.removeRegisteredKey(sectionName, self.property_name + '.')
    listnames = self.listnames
    self.datalist = []
    if not ('alsa_devices' in datamodel.data):
      datamodel.data['alsa_devices'] = []
      
    if self.jack_inputs:
      if not ('alsa_in_devices' in datamodel.data):
        datamodel.data['alsa_in_devices'] = []
  
    if self.jack_outputs:
      if not ('alsa_out_devices' in datamodel.data):
        datamodel.data['alsa_out_devices'] = []
    
    if datamodel_listid:
      datamodel.data[datamodel_listid + ".alsa_in_devices"] = []
      datamodel.data[datamodel_listid + ".alsa_out_devices"] = []
    checkedlist=[]
    for i in range(len(listnames)):
      name = listnames[i]
      element = {}
      self.datalist.append(element)
      element['name'] = name
      if self.property_checked and self.page.field(sectionName + '.bool' + self.property_name + str(i) + '-checked-hide') == True:
        checkedlist.append(name)
        
      if self.jack_inputs:
        if config[sectionName][self.property_name  + str(i) + '-jack_inputs-hide'] != '':
          value = self.page.field(sectionName + '.'+ self.property_name  + str(i) + '-jack_inputs-hide')
          config[sectionName][self.property_name  + '.' + name + '.jack_inputs'] = value
          datamodel.registerkey(sectionName, self.property_name  + '.' + name + '.jack_inputs')
          if not ('jack_connections' in element):
            element['jack_connections'] = {}
          element['jack_connections']['left_jack_inputs'] = datamodel.leftJackInputs(value) 
          element['jack_connections']['right_jack_inputs']= datamodel.rightJackInputs(value)
          for dev in datamodel.alsa_in_devices(value):
            if not (dev in datamodel.data[datamodel_listid + ".alsa_in_devices"]):
              datamodel.data[datamodel_listid + ".alsa_in_devices"].append(dev) 
            if not (dev in datamodel.data["alsa_in_devices"]):
              datamodel.data["alsa_in_devices"].append(dev) 
            if not (dev in datamodel.data["alsa_devices"]):
              datamodel.data["alsa_devices"].append(dev) 
      
      if self.jack_outputs:
        if config[sectionName][self.property_name + str(i) + '-jack_outputs-hide'] != '':
          value = self.page.field(sectionName + '.' + self.property_name   + str(i) + '-jack_outputs-hide')
          config[sectionName][self.property_name  + '.' + name + '.jack_outputs'] = value
          datamodel.registerkey(sectionName, self.property_name  + '.' + name + '.jack_outputs')
          if not ('jack_connections' in element):
            element['jack_connections'] = {}
          element['jack_connections']['left_jack_outputs'] = datamodel.leftJackOutputs(value)
          element['jack_connections']['right_jack_outputs'] = datamodel.rightJackOutputs(value)
          for dev in datamodel.alsa_out_devices(value):
            if not (dev in datamodel.data[datamodel_listid + ".alsa_out_devices"]):
              datamodel.data[datamodel_listid + ".alsa_out_devices"].append(dev) 
            if not (dev in datamodel.data["alsa_out_devices"]):
              datamodel.data["alsa_out_devices"].append(dev) 
            if not (dev in datamodel.data["alsa_devices"]):
              datamodel.data["alsa_devices"].append(dev) 

    if self.property_checked:
      datamodel.registerkey(sectionName, self.property_name + "." + self.property_checked)
      config[sectionName][self.property_name + "." + self.property_checked] = ",".join(checkedlist)
      datamodel.data[sectionName + '.' + self.property_name + "." + self.property_checked + "list"] = checkedlist
    
    if datamodel_listid and (self.jack_inputs or self.jack_outputs):
      datamodel.data[datamodel_listid] = self.datalist
    
  def setFieldCheck(self, index, value):
    self.page.setField(self.page.sectionName + '.bool' + self.property_name + str(index) + '-checked-hide', value)
    
  def setFieldName(self, index, value):
    self.page.setField(self.page.sectionName + '.' + self.property_name   + str(index) + '-name-hide', value)

  def setFieldJackInputs(self, index, value):
    self.page.setField(self.page.sectionName + '.' + self.property_name   + str(index) + '-jack_inputs-hide', value)
    
  def setFieldJackOutputs(self, index, value):
    self.page.setField(self.page.sectionName + '.' + self.property_name   + str(index) + '-jack_outputs-hide', value)
