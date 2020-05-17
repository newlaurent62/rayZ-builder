#!/usr/bin/env python

from PyQt5 import QtGui
from PyQt5 import QtWidgets

class CheckLineEdit(QtWidgets.QWidget):
    def __init__(self, parent=None, message=True):
        super(CheckLineEdit, self).__init__(parent)
        self.message = message
        if self.message:
          self.labelMessage = QtWidgets.QLabel()
        self.lineEdit = QtWidgets.QLineEdit(self)
        self.lineEdit.textChanged.connect(self.check)
        #self.lineEdit.textChanged.connect(self.valueChanged)
        self.labelCheck = QtWidgets.QLabel()
    
    def check(self):
      if self.hasAcceptableInput():
        self.labelCheck.setText('<span style="color:green">' + u'\u2713' + '</span>')
      else:
          self.labelCheck.setText('<span style="color:red">X</span>')
    
    def setEnabled(self, bool):
      self.lineEdit.setEnabled(bool)
    
    def setValidator(self, validator):
      self.lineEdit.setValidator(validator)
    
    def setText(self, text):
      self.lineEdit.setText(text)

    def hasAcceptableInput(self):
      return self.lineEdit.hasAcceptableInput()
        
    def text(self):
      return self.lineEdit.text()

    def addWidgetsTo(self,grid_layout, y, x):
      grid_layout.addWidget(self.lineEdit,y,x)
      grid_layout.addWidget(self.labelCheck,y,x+1)
      if self.message:
        grid_layout.addWidget(self.labelMessage,y,x+2)

    def layout(self):
      hlayout = QtWidgets.QHBoxLayout()
      hlayout.addWidget(self.lineEdit)
      hlayout.addWidget(self.labelCheck)
      
      layout = QtWidgets.QVBoxLayout()
      layout.addLayout(hlayout)
      
      if self.message:
        layout.addWidget(self.labelMessage)
      
      return layout

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