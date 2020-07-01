import gettext
import os

debug = True

# Set the local directory
localedir = 'xxx-LOCALEPATH-xxx'
if not os.path.isabs(localedir):
  localedir = os.path.dirname(__file__) + os.sep + localedir
  
domain = 'xxx-DOMAIN-xxx'

if debug:
  print ('localedir: %s, domain: %s' % (localedir, domain))
  

try:
    traduction = gettext.translation(domain, localedir)
    tr = traduction.gettext
except:
    tr = gettext.gettext

