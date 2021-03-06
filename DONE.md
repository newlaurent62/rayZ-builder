# DONE

## About this file

This file contains a status of things that have been implemented.

see INSTALL.md for notes on rayZ installation

see README.md for notes on rayZ development operations (Makefile targets)

## Resume

### Interprocess communication with catia for the "go to app" feature 

Patch i've done in Catia-fork on github (in cadence from falkTX)

It let you switch to application window related to the jackclient from catia.
A context menu on jackclient boxes with useful app to switch to (the application related to the jackclient or raysession or other application).

Windows switch is declarative, that means when you create a template with rayZ-builder, you declare the applications to load or switch to from catia:

- During the session load, those metadatas are sent to catia using ray_control. Catia polls ray_control every 5 sec for new sessions or closed sessions.
- Metadatas are declared in the session.sh or session.sh snippets (in **&lt;client/&gt;** XML element) used to create the session. 
  They are persisted using ray_control thus this does not work with nsm.

### session_sh supports nsmd and ray-daemon

session.sh file is created from XML in tmpl snippets. The session.xml is build by processing ( "build/.../xi-wizard.xml" + "src/xsl/session_xml.xsl" ) =&gt; ( "build/.../xi-session.xml" + "src/xsl/session_sh.xsl" ) =&gt; session_sh.tmpl .

The ladish has been abandonned by UbuntuStudio so i will not provide ladish generation code. Non-session-manager gives better result and RaySession has been installed in place of non-session-manager. RaySession is fully compatible with nsm protocol.

Currently, nsm and ray session are supported by rayZ-builder. The ray session generated do more things at startup (ray-daemon) that the nsm one. NSMD does not yet have a mechanism to start a script at session startup.

### interface UI and component classes

rayZ-builder has its own gui classes derived from PyQt5. It adds some functions like copyUI that allow to make a clone of a component. It is not a deep clone but it clones the object hierarchy created with **&lt;field/&gt;** or **&lt;group/&gt;** inner XML element parameters.

There is a "group of component" UI that can be tab or list display fields. 
For example, if you have a list of users and you want to input informations for each users with checkbox, line edit, combobox ... It's possible with rayZ-builder generator. (See Jamulus wizard and **&lt;group/&gt;** element)

To create a new UI component:

- create a class that inherits from UI class (see src/gui/rayZ_ui.py)

- modify the src/xsl/wizard.xsl to generate needed code to take advantage of your UI component.

- the UI class should implement:

copyUI : clone the field (for use with **&lt;group/&gt;** components)

readData : initialize the component from config file that has been loaded at wizard startup.

updateData : update config file (in memory) and in json data (in memory). Don't forget to register the added key if any to the datamodel.
in json data, list property key ends with 'list' for example global.users in config file and global.userslist in json data.

### ray-scripts load.sh on RaySession only

The ray session check for required executable when loading. If one or more of the required program are not available during the session load, then raysession prompt a question "ignore or stop loading the session".

It looks also for Jack server running. If not available prompt a question "ignore or stop loading the session". It uses session-dir/jack_parameters file as jack settings.

And It looks for any missing additionnal devices (alsa_in, alsa_out) if any. If one or more devices are not available prompt a question "ignore or stop loading the session".

Some functions on server/service have been added (to check for availability of localhost server such as icecast2.service, mumble-server.service, jamulus.service ...)
see xsl/ray_script_load_sh-gen_tmpl.xsl

### Makefile and wizard source organization

The makefile create a subdir for each wizard build/share/rayZ-builder/session-templates/$(WIZARD_ID)

- this way by changing the prefix to /usr, /usr/local or ~/.local you can easily install wizards to your system
- several wizard can be created : the makefile iterates over the src/wizards/* subdirs
        
One wizard defines the following files and dirs:

- **file : src/wizards/**                         -&gt; contains all wizard main entries (files $(WIZARD_ID).wizard)
- **dir : src/wizards/$(WIZARD_ID)/default**      -&gt; contains all defaults config files. Create a subdir for each application or application conf.
- **dir : src/wizards/$(WIZARD_ID)/pages**        -&gt; contains all wizard pages (files *.page). Pages can be include in wizard file using **&lt;xi:include/&gt;** instruction.
                                                     Pages defines how the templates behave (see **&lt;template/&gt;** and **&lt;template-snippet/&gt;** elements).
- **dir : src/wizards/$(WIZARD_ID)/snippets**     -&gt; contains template snippets (files *.tmpl_snippet) use by pages to generate their conf (session.sh, patch_xml)
- **dir : src/wizards/$(WIZARD_ID)/tmpl**         -&gt; Cheetah templates (files *.tmpl). Create one when you need to fill a configuration file depending on user inputs. Those files should go to a .config path
- **dir : src/wizards/$(WIZARD_ID)/test-data**    -&gt; contains a datamodel.json that can be use by Makefile to test a template
- **dir : src/wizards/$(WIZARD_ID)/xsl**          -&gt; contains custom added or custom xsl ... (Makefile has to be modified for each custom xsl added)
    
Global dirs:

- **dir : src/xsd** : contains schema definition (constraints on wizards XML declaration)
- **dir : src/xsl** : contains xsl file that are used by all wizards
- **dir : src/gui** : contains custom UI components
- **dir : src/bin** : contains wrapper scripts used by the created session 
      
### file types from rayZ-builder project

Document file types: 

- wizard files ***.wizard** : XML file containing a wizard declaration. It can include *.page
- page files ***.page** : XML file containing a page declaration. It can include *.tmpl_snippet
- tmpl snippet files ***.tmpl_snippet** : Cheetah template snippet for session_sh and patch_xml of a page. A Cheetah snippet can be reused by several pages
- tmpl files ***.tmpl** : Cheetah Cheetah template for configuration files creation

wizard, page and tmpl_snippet have to be in the same directory when combined to a single xml (done in the Makefile) because of **&lt;xi:include/&gt;** XML processing instructions.

a wizard is composed of one or more setup pages.
Before walking through the wizard steps, the final user selects the pages (applications related) he wants to use.

- Each wizard page is required or optional. The optional page can be added to the wizard steps by the user.
- Group of optional pages can be created. The user select one of these page.

### Declarative XML

Declarative XML file means that you input an XML file and this XML will be processed by the Makefile to generate a wizard and template python classes.

The XML file format is a schema that contains wizard informations such as title, description, author, keywords, category, version, software requirements as well as pages and templates description.
