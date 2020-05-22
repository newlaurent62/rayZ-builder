# TODO

## Wizard for Jamulus and related software

Jamulus, jack_capture ok, obs (icecast2_audio, icecast2_video) to test
TOODO:
  Mumble
  Audacity
  Reaper
  Start Jamulus server with recording option
  
## Overall 

- Commenter les XSLs, XSDs, Page, Wizard (Description)

- at the opening of the raysession, check for program availabilities

- Use client Proxy in raysession
    => set the save level of each application in the ray-proxy xml files (created by raysession.sh snippets).
  
- Schema creation :
  More contraint checks on dependencies and types
  #in progress

- document the examples

- handle QListWidget (with checkbox / radio) type and QTableWidget ?

- check that all required programs are available on the system (check version ?) depending on the section declared in the conf file or datamodel.json. 

- Check that variables are not using reserved variable names and that they are uniq in the xml file.
  

## Done

=> OK : Create a load.sh ray-scripts that check for servers started, additionnal audio devices (alsa_in and alsa_out) and for programs availability.

=> OK : the makefile create a subdir for each wizard build/raysession-templates/$(WIZARD_ID)
    - this way by changing the prefix to usr/share or whatever you can easily install wizards to your system
    - several wizard can be created : the makefile iterates over the src/wizards/* subdirs
    
    make : generates all wizards
    make build : generates configured DEFAULT_WIZARD
    make exec : start the DEFAULT_WIZARD wizard
    make test-template : fill the DEFAULT_WIZARD template
    make fill-template : fill the DEFAULT_WIZARD template and start raysession gui
    make install : install the script wrapper needed to start client in the created raysession
    make uninstall : uninstall the script wrapper 
    
    One wizards defines the following files and dirs:
      - $(WIZARD_ID).wizard
      - default dir : contains all defaults needed default .config files. Create a subdir for each application or application conf.
      - pages : contains all wizard pages. (Note: a page shall be related to one client and only one) 
        - pages defines how the template behave for this client (see <template/> and <template-snippet/> elements).
      - snippets : template snippets use by pages to generate their conf (raysession_xml, patch_xml and raysession_sh)
      - tmpl : Cheetah templates when the need to fill a configuration is needed to create the .config path
      - test-data : contains a datamodel.json that can be use by Makefile to test to fill the default selected template (See DEFAULT_WIZARD variable in the Makefile)
      - xsl : xsl allow to access to xml content and create Cheetah tmpl file or others.
    
=>  OK : document file types: 
    - wizard files *.wizard : XML file containing a wizard declaration. It can include *.page
    - page files *.page : XML file containing a page declaration. It can include *.tmpl_snippet
    - tmpl snippet files *.tmpl_snippet : Cheetah template snippet for raysession_sh and patch_xml of a page. A Cheetah snippet can be reused by several pages
    - tmpl files *.tmpl : Cheetah Cheetah template for configuration files creation
    wizard, page and tmpl_snippet have to be in the same directory when combined to a single xml (done in the Makefile) because of <xi:include/> XML processing instructions.

=> OK : a wizard is composed of several configuration pages.
  The user selects the pages (applications related) he wants to use.
    - Each page is required or optional
    - Group of pages options can be created. 
      The user select one of these page to be used
  Each page should be related only to one and only one client.
  A page defines:
    - a raysession_sh tmpl snippet that let register this page related client(s) with the selected options to raysession (bash format)
    - patch_xml tmpl snippet that let setup jack connections clients related to this page (XML format)
    - any templates needed to create a set of initial configuration files suitable for the use case defined by the wizard

=>  OK generate a single point entry to each template that create a filltemplate given a JSON data structure
    This point entry will create a raysession (default) or just fill the template (--fill-only)

=>  OK syntax checking on XML and bash script (only bash supported by now)

=>  OK Create a declarative template mechanism 
    only XML code + Cheetah needed to create a raysession template (no need for python code)

=>  template versionning : add a version in the template name : mywizard_v1

=>  option to start RaySession gui at the end of the document creation process

=>  create an XML file describing each wizard page (title, description, author, keywords, category, version, software requirements) from the main XML file
    one wizard page related to one application configuration
