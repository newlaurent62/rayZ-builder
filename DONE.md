# DONE

## About this file

This file contains a status of things that have been implemented.

see INSTALL.md for notes on rayZ installation

see README.md for notes on rayZ development operations (Makefile targets)

## Resume

### Interprocess communication with catia for the "go to app" feature 

Patch i've done in Catia-fork on github (in cadence from falkTX)

It let you switch to application window related to the jackclient from catia.
A context menu on jackclient boxes propose some context menu options with useful app to switch to (the application related to the jackclient or raysession or other application).

Synchronization is declarative, that means when you create a template with rayZ-builder, you declare the applications to load or switch to from catia:

- During the session load, these metadatas are sent to catia in /tmp/catia. Catia polls the directory every 5 sec.
- Metadatas are declared in the session.sh or session.sh snippets used to create the session. 
  They are write to $session_path/default/metadata-jackclients.yml. It can be modified manually.

### ray-scripts load.sh

The ray session check for required executable of the document being loaded. If one or more of the required program are not available during the session load, then raysession prompt a question "ignore or stop loading the session".

It looks also for Jack server running. If not available prompt a question "ignore or stop loading the session".

And It looks for any additionnal devices (alsa_in, alsa_out) if any. If one or more devices are not available prompt a question "ignore or stop loading the session".

Some functions on server/service have been added (to check for availability of localhost server such as icecast2.service, mumble-server.service, jamulus.service ...)
see xsl/ray_script_load_sh-gen_tmpl.xsl

### Makefile and wizard source organization
The makefile create a subdir for each wizard build/share/rayZ-builder/session-templates/$(WIZARD_ID)

- this way by changing the prefix to /usr, /usr/local or ~/.local you can easily install wizards to your system
- several wizard can be created : the makefile iterates over the src/wizards/* subdirs
        
One wizard defines the following files and dirs:

- file : src/wizards/$(WIZARD_ID).wizard
- dir : src/wizards/$(WIZARD_ID)/default      -> contains all defaults needed .config files. Create a subdir for each application or application conf.
- dir : src/wizards/$(WIZARD_ID)/pages        -> contains all wizard pages. Pages can be include in wizard file using <xi:include/> instruction.
                                                 Pages defines how the template behave (see <template/> and <template-snippet/> elements).
- dir : src/wizards/$(WIZARD_ID)/snippets     -> contains template snippets use by pages to generate their conf (session.sh, patch_xml)
- dir : src/wizards/$(WIZARD_ID)/tmpl         -> Cheetah templates. Create one when you need to fill a configuration file depending on user inputs. Those files should go to a .config path
- dir : src/wizards/$(WIZARD_ID)/test-data    -> contains a datamodel.json that can be use by Makefile to test a template
- dir : src/wizards/$(WIZARD_ID)/xsl          -> contains custom added or custom xsl ... (Makefile has to be modified for each xsl)
- dir : ray-scripts                           -> contains ray session scripts for defining custom behaviour during load, save or close operation
    
Global dirs:

- xsd : contains schema definition (constraints on wizards XML declaration)
- xsl : contains xsl file that are used by all wizards
- gui : contains custom UI components
- bin : contains wrapper scripts used by the created session 
      
### file types from rayZ-builder project
Document file types: 

- wizard files *.wizard : XML file containing a wizard declaration. It can include *.page
- page files *.page : XML file containing a page declaration. It can include *.tmpl_snippet
- tmpl snippet files *.tmpl_snippet : Cheetah template snippet for raysession_sh and patch_xml of a page. A Cheetah snippet can be reused by several pages
- tmpl files *.tmpl : Cheetah Cheetah template for configuration files creation

wizard, page and tmpl_snippet have to be in the same directory when combined to a single xml (done in the Makefile) because of <xi:include/> XML processing instructions.

a wizard is composed of one or more setup pages.
Before walking through the wizard steps, the final user selects the pages (applications related) he wants to use.

- Each wizard page is required or optional. The optional page can be added to the wizard steps by the user.
- Group of optional pages can be created. The user select one of these page.

### Declarative XML

Declarative XML file means that you input an XML file and this XML will be processed by the Makefile to generate a wizard and template python classes.

The XML file format is a schema that contains wizard informations such as title, description, author, keywords, category, version, software requirements as well as pages and templates description.
