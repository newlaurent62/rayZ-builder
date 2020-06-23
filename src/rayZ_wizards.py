#!/usr/bin/env python
import getopt
import sys
from PyQt5 import QtGui
from PyQt5 import QtCore, QtWidgets
import sys
import os
import xml.etree.ElementTree as ET
import configparser

_debug = False

# Subclass QMainWindow to customise your application's main window
class MainWindow(QtWidgets.QWidget):

  def __init__(self, rayZtemplatesdir, *args, **kwargs):
    super(MainWindow, self).__init__(*args, **kwargs)

    self.wizardDict = {}    
    self.listOfWizard = []

    self.initUI()
      
  
  def initUI(self):
    self.setWindowTitle("wizards from rayZ-builder")

    self.description = QtWidgets.QLabel("This application gives you access to all installed <b>rayZ wizards</b>. <br/><br/>These wizards let you create <i>simple or complex audio virtual studio setup </i>!<br/><br/>You can generate <b>NSM Sessions</b> or <b>Ray Sessions</b>.<br/><br/><br/>")

    self.labelType = QtWidgets.QLabel('Select the session type you want to generate at the end of the wizard steps')
    self.comboBoxType = QtWidgets.QComboBox(self)
    self.comboBoxType.insertItem(0,'ray_control')
    self.comboBoxType.insertItem(1, 'nsm')

    self.labelWizards = QtWidgets.QLabel("Click on the wizard you want to execute")

    self.listWidgetWizard = QtWidgets.QListWidget(self)
    
    self.initListOfWizard(rayZtemplatesdir)
    for i in range(len(self.listOfWizard)):
      self.listWidgetWizard.insertItem(i, self.listOfWizard[i])

    self.listWidgetWizard.clicked.connect(self.startWizard)
    
    layout = QtWidgets.QVBoxLayout()
    layout.addWidget(self.description)
    layout.addWidget(self.labelType)
    layout.addWidget(self.comboBoxType)
    layout.addWidget(self.labelWizards)
    layout.addWidget(self.listWidgetWizard)
    
    self.setLayout(layout)
    self.show()

  def startWizard(self):
    _path = self.wizardDict[self.listWidgetWizard.currentItem().text()]['path']
    sys.path.append(_path)
    command = "/usr/bin/env python3 " + _path + os.sep + "wizard.py --start-gui-option --session-manager=" + self.comboBoxType.currentText()
    try:
      os.system(command)
    except:
      print("Unexpected error:", sys.exc_info()[0] + "\nExecuting the command: '" + command + "'")
      QtWidgets.QMessageBox.critical(self,
                                          "Starting wizard ...",
                                          "An unexpected error occured during the wizard execution !")      
    
  def initListOfWizard(self, rayZtemplatesdir):
    _dirs = os.listdir(rayZtemplatesdir)
    _bkpsyspath = sys.path
    for _dir in _dirs:
      _path = rayZtemplatesdir + os.sep + _dir
      if os.path.isdir(_path):
        try:
          print ('#-- Try to find : "' + _dir + '" in ' + str(_path))
          _tree = ET.parse(_path + os.sep + 'info_wizard.xml')
          _root = _tree.getroot()
          
          _info = _root.find('info')
          _title = _info.find("title").text
          _version = _info.find("version").text
          _label = _title + " ( v" + _version + ")"
          self.listOfWizard.append(_label)
          self.wizardDict[_label] = {}
          self.wizardDict[_label]['path'] = _path
          self.wizardDict[_label]['xmlinfo'] = _root
        except:
          print("Unexpected error:", sys.exc_info()[0])
          pass
      sys.path = _bkpsyspath
    if len(self.listOfWizard) == 0:
      QtWidgets.QMessageBox.critical(self,
                                    "wizards ...",
                                    "No wizards could be found in " + str(rayZtemplatesdir) + " !")
      sys.exit(2)

def startWizard(wizardid, session_manager):
  _path = rayZtemplatesdir + os.sep + wizardid
  sys.path.append(_path)
  command = "/usr/bin/env python3 " + _path + os.sep + "wizard.py --start-gui-option --session-manager=" + session_manager
  try:
    os.system(command)
  except:
    print("Unexpected error:", sys.exc_info()[0] + "\nExecuting the command: '" + command + "'")

def usage():
  print ("Usage:")
  print ("rayZ_wizards [options)")
  print ("   -h|--help              : print this help text")
  print ("   -c|--conf-file         : set the conf filename to read/write")
  print ("   -m|--session-manager   : set the session-manager of the resulting document")
  print ("                             - ray_control : (default) create a raysession document. You will need raysession software for the processing,")
  print ("                             - nsm         : create a nsm session. You wont need non-session-manager for the document generation,")
        
if __name__ == '__main__':
  rayZtemplatesdir = 'xxx-TEMPLATES_DIR-xxx'
  conffilename = None
  session_manager = 'ray_control'
  
  try:                                
    opts, args = getopt.getopt(sys.argv[1:], "hdt:c:m:", ["help", "debug","templates-dir=","conf-file=", "sesssion-manager="])
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
      _debug = False              
    elif opt in ("-m", "--session-manager"):
      session_manager = arg
      if session_manager not in ('ray_control', 'nsm'):
        raise Exception('Unknown session manager: %s' % session_manager)
      print ('will generate a session using %s' % session_manager)
    elif opt in ("-c", "--conf-file"):
      conffilename = arg
      print ("will read/write conf file '%s'" % conffilename)
    elif opt in ("-t", "templates-dir"):
      rayZtemplatesdir = arg
      if not os.path.isdir(rayZtemplatesdir):
        print ("templates-dir argument must be a directory !")
        sys.exit(2)

  if conffilename:
    config = configparser.ConfigParser()
    if os.path.isfile(conffilename):      
      config.read(conffilename)
      if 'wizard' in config.sections() and 'id' in config['wizard']:
        print ('Reading ' + conffilename)
        wizardid = config['wizard']['id']
        print ('Try to load "%s" wizard ...' % wizardid)
        startWizard(wizardid, session_manager)
        sys.exit()
      else:
        print('Cannot determine the wizard to load ... "id" property of [wizard] section is missing !')
    else:
      print('Could not find conf file "%s"' % conffilename)
      
  app = QtWidgets.QApplication(sys.argv)
  mainWindow = MainWindow(rayZtemplatesdir)
  mainWindow.show()

  sys.exit(app.exec_())
