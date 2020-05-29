This file contains a status of things that have been implemented.

see INSTALL.md for notes on rayZ installation

see README.md for notes on rayZ development operations (Makefile targets)


=>  == Patch i've done in Catia-fork on github (in cadence from falkTX) ==
  It let you switch to the desired application from catia. 
  A context menu on jackclient boxes propose menu options with useful app to switch to (the application related to the jackclient or raysession or other application).
  Synchronization is declarative, that means when you create a template with rayZ-builder,
    
  you declare the applications to load or siwtch to in catia from the raysession:
  - During the session load, these metadatas are sent to catia in /tmp/catia. Catia polls the directory every 5 sec.
  - Metadata are declared in the session.sh or session.sh snippets used to create the session.
  A file in $session_path/default/metadata-clients.yml can also be modified manually.
    
=>  The ray session search for required executable. If not available during the session load, then prompt a question "ignore or stop loading the session".
  It looks for Jack server running. If not available prompt a question "ignore or stop loading the session".
  It looks for any additionnal devices (alsa_in, alsa_out) if any. If one or more devices are not available prompt a question "ignore or stop loading the session".
  Some function on server/service have been added (to check for availability of localhost server such as icecast2.service, mumble-server.service, jamulus.service ...)
  see xsl/ray_script_load_sh-gen_tmpl.xsl

=>  The makefile create a subdir for each wizard build/share/rayZ-builder/session-templates/$(WIZARD_ID)
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
      
    
=>  Document file types: 
    - wizard files *.wizard : XML file containing a wizard declaration. It can include *.page
    - page files *.page : XML file containing a page declaration. It can include *.tmpl_snippet
    - tmpl snippet files *.tmpl_snippet : Cheetah template snippet for raysession_sh and patch_xml of a page. A Cheetah snippet can be reused by several pages
    - tmpl files *.tmpl : Cheetah Cheetah template for configuration files creation
    wizard, page and tmpl_snippet have to be in the same directory when combined to a single xml (done in the Makefile) because of <xi:include/> XML processing instructions.

=>  a wizard is composed of one or more setup pages.
    The user selects the pages (applications related) he wants to use.
    - Each page is required or optional
    - Group of optional pages can be created. The user select one of these page to be used

=>  Wizard/Template information: tag info added to the wizard XML file declaration. (id, title, author, version, keywords, category, description)

=>  option to start RaySession gui at the end of the document creation process

=>  create an XML file describing each wizard page (title, description, author, keywords, category, version, software requirements) from the main XML file
    one wizard page related to one application configuration
