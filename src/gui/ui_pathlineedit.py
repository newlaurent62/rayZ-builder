#!/usr/bin/env python

from PyQt5 import QtGui
from PyQt5 import QtWidgets
import os

class PathLineEdit(QtWidgets.QWidget):
      
    Type_File = 1
    Type_Dir = 2
    
    def __init__(self, parent=None, filtertype = None, filedialogtype = 1, message=True):
        super(PathLineEdit, self).__init__(parent)
        self.message = message
        if self.message:
          self.labelMessage = QtWidgets.QLabel()
        self.lineEdit = QtWidgets.QLineEdit(self)
        self.lineEdit.textChanged.connect(self.check)
        self.lineEdit.setReadOnly(True)
        self.filedialogtype = filedialogtype
        self.filtertype = filtertype
        self.buttonOpen = QtWidgets.QPushButton('Select', self)
        self.buttonOpen.clicked.connect(self.openfiledialog)
        #self.lineEdit.textChanged.connect(self.valueChanged)
        self.labelCheck = QtWidgets.QLabel()
    
    def openfiledialog(self):
      if self.filedialogtype == self.Type_File:
        self.lineEdit.setText(QtWidgets.QFileDialog.getOpenFileName(self, 'Select a file', './',self.filtertype))
        acceptableInput = True
      elif self.filedialogtype == self.Type_Dir:
        self.lineEdit.setText(QtWidgets.QFileDialog.getExistingDirectory(self, 'Select a directory', './',QtWidgets.QFileDialog.ShowDirsOnly
                                       | QtWidgets.QFileDialog.DontResolveSymlinks))
        acceptableInput = True
      else:
        raise Exception('Unknown filedialogtype !')
      
    def check(self):
      if self.hasAcceptableInput():
        self.labelCheck.setText('<span style="color:green">' + u'\u2713' + '</span>')
      else:
          self.labelCheck.setText('<span style="color:red">X</span>')
    
    def setEnabled(self, bool):
      self.lineEdit.setEnabled(bool)
        
    def setText(self, text):
      self.lineEdit.setText(text)

    def hasAcceptableInput(self):
      path = self.lineEdit.text()
      if self.filedialogtype == self.Type_File and path != '' and os.path.isfile(path):
        return True
      elif self.filedialogtype == self.Type_Dir and path != '' and os.path.isdir(path):
        return True
      else:
        return False
        
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
      hlayout.addWidget(self.buttonOpen)
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
      
