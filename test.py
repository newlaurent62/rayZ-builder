#import Jamulus
import os
import sys

def listOfWizard(rayZtemplatesdir):
  _dirs = os.listdir(rayZtemplatesdir)
  _result = []
  bkpsyspath = sys.path
  for _dir in _dirs:
    _path = rayZtemplatesdir + os.sep + _dir
    if os.path.isdir(_path):
      try:
        print ('#-- Try to load : "' + _dir + '" in ' + str(_path))
        sys.path.append(_path)
        print ('sys.path' + str(sys.path))
        from info_wizard import WizardInfo
        from tmpl_wizard import SessionTemplate
        info = WizardInfo()
        _result.append((info._id,info._title))
      except ImportError as e:
        print (e)
        pass
      except:
        print("Unexpected error:", sys.exc_info()[0])
        pass
    sys.path = bkpsyspath
  return _result

print(listOfWizard("build/share/rayZ-builder/session-templates"))
