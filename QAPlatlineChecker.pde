import sftp.*;
import java.util.Collections;
import java.util.List;

/*
 * Reads in a list of street TSIDs from a QAPlatlines_config.json file, and for  each  of
 * these streets, an image is generated of a grey street with platlines marked, together
 * with a spice tree in each tree location. This means it will be easy to see whether the
 * platlines are low enough to work with spice trees, which are most likely to clash
 * with platlines. 
 * This tool also allows platlines to be somewhat validated because any obvious gaps at the edges
 * or hidden behind foreground scenery will also be exposed.
 *
 * This tool needs to be run after QABot - so that is uses the most up to date tree x,y values.
 *
 * It has been designed as a separate tool to QABot as it is expected that this tool may be run several
 * times for a street, checking that any moved platlines have fixed the problem
 */

// Directory where QAPlatlines_config.json is
String workingDir;
// Contains all the info read in from QAPlatlines_config.json
ConfigInfo configInfo = null;

// Information for this street i.e. the snaps of the street, items on the street
StreetInfo streetInfo;

// Keep track of which street we are on in the list from the QAPlatlines_config.json file
int streetBeingProcessed;

// Handles all output to screen
DisplayMgr displayMgr;
String uploadString;
String downloadString;

// Handles connection to server
Sftp QAsftp;

// Handles all text output
OutputFile debugOutput;
OutputFile infoOutput;

// Spice tree image
PNGFile spiceTreePNGImage;
PNGFile spiceTreeOutlinePNGImage;

// States - used to determine next actions
int nextAction;
final static int USER_INPUT_CONFIG_FOLDER = 10;
final static int CONTINUE_SETUP = 11;
final static int WAIT_FOR_SERVER_START = 20;
final static int INIT_STREET = 40;
final static int INIT_ITEM_DATA = 41;
final static int SHOW_FAILED_STREET_MSG = 42;
final static int PROCESS_STREET = 50;
final static int SHOW_FAILED_STREETS_MSG = 70;
final static int WAITING_FOR_INPUT = 80;
final static int IDLING = 100;
final static int EXIT_NOW = 110;

// Differentiate between error/normal endings
boolean failNow = false;    // abnormal ending/error

// Contains both debug and user input information output files
PrintToFile printToFile;
// 0 = no debug info 1=all debug info (useful for detailed stuff, rarely used), 
// 2= general tracing info 3= error debug info only
// This will be reset when the QAPlatlines_config.json is read
int debugLevel = 3;
boolean debugToConsole = true;

Memory memory = new Memory();

public void setup() 
{
    // Set size of Processing window
    // width, height
    // Must be first line in setup()
    //size(1200,800);
    size(1200,700); 
    
    // Used for final application title bar
    surface.setTitle("QA tool for seeing if spice trees overlap platlines"); 
    
    // Used to handle different ways user can close the program
    prepareExitHandler();
    
    nextAction = 0;
    
    // Start up display manager
    displayMgr = new DisplayMgr();
    displayMgr.clearDisplay();
    
    printToFile = new PrintToFile();
    if (!printToFile.readOkFlag())
    {
        println("Error setting up printToFile object");
        displayMgr.showErrMsg("Error setting up printToFile object", true);
        failNow = true;
        return;
    }
                     
    // Find the directory that contains the QAPlatlines_config.json 
    workingDir = "";
    if (!validConfigJSONLocation())
    {
        nextAction = USER_INPUT_CONFIG_FOLDER;
        selectInput("Select QAPlatlines_config.json in working folder:", "configJSONFileSelected");
    }
    else
    {
        nextAction = CONTINUE_SETUP;
    }

}

public void draw() 
{  
    String currentItemTSID;

    // Each time we enter the loop check for error/end flags
    if (failNow)
    {
        // Give the user a chance to see any saved error message which could not be displayed earlier
        // In particular when user selected invalid QAPlatlines_config.json (e.g. with hidden .txt suffix)
        displayMgr.showSavedErrMsg();       
        nextAction = WAITING_FOR_INPUT;
    }
    
    // Carry out processing depending on whether setting up the street or processing it
    //println("nextAction is ", nextAction);
    //memory.printMemoryUsage();
    //memory.printUsedMemory("start");
    switch (nextAction)
    {
        case IDLING:
        case WAITING_FOR_INPUT:
            break;
            
        case USER_INPUT_CONFIG_FOLDER:
            // Need to get user to input valid location of QAPlatlines_config.json
            // Come here whilst wait for user to select the input
            if (workingDir.length() > 0)
            {
                nextAction = CONTINUE_SETUP;
            }
            break;
            
        case CONTINUE_SETUP:
        
            // Now we have the working directory, we can set up the debug output file - so can report useful QAPlatlines_config.json errors
            if (!printToFile.initPrintToDebugFile())
            {
                println("Error creating debug output file");
                displayMgr.showErrMsg("Error creating debug output file", true);
                failNow = true;
                return;
            }

            // Set up config data
            configInfo = new ConfigInfo();
            if (!configInfo.readOkFlag())
            {
                // Error message already set up in this function
                failNow = true;
                return;
            }
    
            // Set up output file
            if (!printToFile.initPrintToOutputFile())
            {
                println("Error opening output file");
                displayMgr.showErrMsg("Error opening output file", true);
                failNow = true;
                return;
            }
                      
            printToFile.printDebugLine(this, "Timestamp: " + nf(hour(),2) + nf(minute(),2) + nf(second(),2), 1);
    
            if (configInfo.readTotalJSONStreetCount() < 1)
            {
                // No streets to process - exit
                printToFile.printDebugLine(this, "No streets to process - exiting", 3);
                displayMgr.showErrMsg("No streets to process - exiting", true);
                failNow = true;
                return;
            }

            if (!setupWorkingDirectories())
            {
                printToFile.printDebugLine(this, "Problems creating working directories", 3);
                displayMgr.showErrMsg("Problems creating working directories", true);
                failNow = true;
                return;
            }
            
            // Load up images of spice tree - the purple one is used when a street snap forms the background
            spiceTreePNGImage = new PNGFile("trant_spice_10_root_clearance.png", false);            
            if (!spiceTreePNGImage.setupPNGImage())
            {
                printToFile.printDebugLine(this, "Problems loading image of spice tree", 3);
                displayMgr.showErrMsg("Problems loading image of spice tree", true);
                failNow = true;
                return;
            }
            spiceTreeOutlinePNGImage = new PNGFile("trant_spice_outline_root_clearance.png", false);            
            if (!spiceTreeOutlinePNGImage.setupPNGImage())
            {
                printToFile.printDebugLine(this, "Problems loading outline image of spice tree", 3);
                displayMgr.showErrMsg("Problems loading outline image of spice tree", true);
                failNow = true;
                return;
            }
            
            // Set up connection to remote server if not using vagrant
            if (!configInfo.readUseVagrantFlag())
            {

                QAsftp = new Sftp(configInfo.readServerName(), configInfo.readServerUsername(), false, configInfo.readServerPort());  
                QAsftp.setPassword(configInfo.readServerPassword());
                QAsftp.start(); // start the thread
                displayMgr.showInfoMsg("Connecting to server ... please wait");
                nextAction = WAIT_FOR_SERVER_START;
            }
            else
            {
                QAsftp = null;
    
                // Ready to start with first street
                streetBeingProcessed = 0;            
                displayMgr.clearDisplay();
                displayMgr.showInfoMsg(downloadString + " street JSON files for street " + configInfo.readStreetTSID(streetBeingProcessed) + " ... please wait");
                nextAction = INIT_STREET;
    
                // Display start up msg
                displayMgr.clearDisplay();
                displayMgr.showInfoMsg("Copying street/item JSON files for street " + configInfo.readStreetTSID(streetBeingProcessed) + " ... please wait");
            }
            break;
            
        case WAIT_FOR_SERVER_START:
            
            if (QAsftp != null)
            {
                if (QAsftp.readSessionConnect())
                {
                    // Server has been connected successfully - so can continue
                    printToFile.printDebugLine(this, "Timestamp: " + nf(hour(),2) + nf(minute(),2) + nf(second(),2), 1);
                    // First validate the fixtures/persdata/persdata-qa paths on the server
                    if (!QAsftp.executeCommand("ls", configInfo.readFixturesPath(), "silent"))
                    {
                        println("Fixtures directory ", configInfo.readFixturesPath(), " does not exist on server");
                        displayMgr.showErrMsg("Fixtures directory " + configInfo.readFixturesPath() + " does not exist on server", true);
                        failNow = true;
                        return;
                    }
                    if (!QAsftp.executeCommand("ls", configInfo.readPersdataPath(), "silent"))
                    {
                        println("Persdata directory ", configInfo.readPersdataPath(), " does not exist on server");
                        displayMgr.showErrMsg("Persdata directory " + configInfo.readPersdataPath() + " does not exist on server", true);
                        failNow = true;
                        return;
                    }
    
                    // Ready to start with first street
                    streetBeingProcessed = 0;            
                    displayMgr.clearDisplay();
                    displayMgr.showInfoMsg(downloadString + " street JSON files for street " + configInfo.readStreetTSID(streetBeingProcessed) + " ... please wait");
                    nextAction = INIT_STREET;
                }
                else
                {
                    // Session still not connected
                    // Abort if the error flag is set
                    if (!QAsftp.readRunningFlag())
                    {
                        displayMgr.showErrMsg("Problems connecting to server", true);
                        failNow = true;
                        return;
                    }
                }
            }
            break;
            
        case INIT_STREET:
            // Carries out the setting up of the street and associated items 
            printToFile.printDebugLine(this, "Timestamp: " + nf(hour(),2) + nf(minute(),2) + nf(second(),2), 1);        
            printToFile.printDebugLine(this, "Read street data for TSID " + configInfo.readStreetTSID(streetBeingProcessed), 2);
                       
            if (!initialiseStreet())
            {
                // fatal error
                displayMgr.showErrMsg("Error setting up street data", true);
                failNow = true;
                return;
            }
            
            if (streetInfo.readInvalidStreet())
            {
                // The L* or G* file is missing for this street, or invalid data of some sort - so skip the street       
                // Display the start up error messages
                displayMgr.showThisSkippedStreetMsg(true);
                nextAction = SHOW_FAILED_STREET_MSG;
                return;
            }
            else if (streetInfo.readSkipStreet())
            {
                displayMgr.showThisSkippedStreetMsg(false);
                nextAction = SHOW_FAILED_STREET_MSG;
                return;
            }
            
            memory.printMemoryUsage();
            currentItemTSID = streetInfo.readCurrentItemTSIDBeingProcessed();
            if (currentItemTSID.length() == 0)
            {
                failNow = true;
                return;
            }
            displayMgr.showInfoMsg(downloadString + " item JSON file " + currentItemTSID + ".json for street " + configInfo.readStreetTSID(streetBeingProcessed) + " ... please wait");
            nextAction = INIT_ITEM_DATA;
            break;
            
        case SHOW_FAILED_STREET_MSG:
           // pause things for 5 seconds for actual errors - so user can see previous output about failed street - then move on to next one
            if (streetInfo.readInvalidStreet())
            {
                delay(5000);
            }
            else
            {
                // Just delay for 1s to show skipping street for legitimate reasons
                delay(1000);
            }
            displayMgr.clearDisplay();
            streetBeingProcessed++;
            if (streetBeingProcessed >= configInfo.readTotalJSONStreetCount())
            {
                // Reached end of list of streets - normal ending
                boolean nothingToShow = displayMgr.showAllSkippedStreetsMsg(); 
                String duration = "(" + printToFile.scanDuration() + ")";
                printToFile.printOutputLine("\n\nALL PROCESSING COMPLETED " + duration + "\n\n");
                printToFile.printDebugLine(this, "Exit now - All processing completed " + duration, 3);
                if (nothingToShow)
                {
                    // Display success message as no error message present
                    displayMgr.showSuccessMsg();
                }
                nextAction = WAITING_FOR_INPUT;
                return;
            }
            displayMgr.showInfoMsg(downloadString + " street JSON files for street " + configInfo.readStreetTSID(streetBeingProcessed) + " ... please wait");
            nextAction = INIT_STREET;
            break;
            
        case INIT_ITEM_DATA:
            printToFile.printDebugLine(this, "Timestamp: " + nf(hour(),2) + nf(minute(),2) + nf(second(),2), 1);
            
            // NEED TO LOOP THROUGH THIS UNTIL ALL ITEMS INIT/JSONS GOT
            // shoud we also get it to show a display message for each JSON??? 
            // would be done
            
            // If fails to load I* file - then give up - means the server connection is down or problems copying files
            if (!streetInfo.readStreetItemData())
            {
                // Error message set by this function
                println("Error detected in readStreetItemData");
                failNow = true;
                return;
            }
            
            if (streetInfo.readStreetInitialisationFinished())
            {
                // Loaded up all the information from street and item JSON files - can now start processing this street
                printToFile.printDebugLine(this, "street initialised is " + configInfo.readStreetTSID(streetBeingProcessed) + " (" + streetBeingProcessed + ")", 1);
                memory.printMemoryUsage();
                nextAction = PROCESS_STREET;
            }
            else
            {
                currentItemTSID = streetInfo.readCurrentItemTSIDBeingProcessed();
                if (currentItemTSID.length() == 0)
                {
                    failNow = true;
                    return;
                }
                displayMgr.showInfoMsg(downloadString + " item JSON file " + currentItemTSID + ".json for street " + configInfo.readStreetTSID(streetBeingProcessed) + " ... please wait");
            }
            break;
            
        case PROCESS_STREET:
            // Process the street, now that we have all the JSON items
            printToFile.printDebugLine(this, "Processing street  " + streetBeingProcessed, 1);
            if (!streetInfo.processStreet())
            {
                failNow = true;
                return;
            }

            // Move on to next street
            streetBeingProcessed++;
            if (streetBeingProcessed >= configInfo.readTotalJSONStreetCount())
            {
                // Reached end of list of streets - normal ending
                // Print out final count of trees
                infoOutput.printFinalCountData();
                streetInfo = null;
                System.gc();
                    
                // Display any messages about failed streets before ending
                nextAction = SHOW_FAILED_STREETS_MSG;
            }
            else
            {
                displayMgr.showInfoMsg(downloadString + " street JSON files for street " + configInfo.readStreetTSID(streetBeingProcessed) + " ... please wait");
                nextAction = INIT_STREET;
            }

            //printToFile.printDebugLine(this, "End top level processStreet memory", 1);
            //memory.printMemoryUsage();
            break;
          
        case SHOW_FAILED_STREETS_MSG:
            boolean nothingToShow = displayMgr.showAllSkippedStreetsMsg();  
            String duration = "(" + printToFile.scanDuration() + ")";
            printToFile.printOutputLine("\n\nALL PROCESSING COMPLETED " + duration + "\n\n");
            printToFile.printDebugLine(this, "Exit now - All processing completed " + duration, 3);
            if (nothingToShow)
            {
                // Can go ahead and display success message as there are no error messages to show
                displayMgr.showSuccessMsg();
            }
            nextAction = WAITING_FOR_INPUT;
            break;
            
        case EXIT_NOW: 
            doExitCleanUp();
            memory.printMemoryUsage();
            exit();
            break;
           
        default:
            // Error condition
            printToFile.printDebugLine(this, "Unexpected next action - " + nextAction, 3);
            exit();
    }
    //memory.printUsedMemory("end");
}

void doExitCleanUp()
{

    // Close sftp session
    if (QAsftp != null && QAsftp.readRunningFlag())
    {
        if (!QAsftp.executeCommand("exit", "session", null))
        {
            println("exit session failed");
        }
    }
    
    // Close the output/debug files
    printToFile.closeOutputFile();
    printToFile.closeDebugFile();

}

boolean initialiseStreet()
{       
    // Initialise street and then loads up the items on that street.
    displayMgr.clearDisplay();
    
    String streetTSID = configInfo.readStreetTSID(streetBeingProcessed);
    if (streetTSID.length() == 0)
    {
        // Failure to retrieve TSID
        printToFile.printDebugLine(this, "Failed to read street TSID number " + str(streetBeingProcessed) + " from QAPlatlines_config.json", 3); 
        return false;
    }
    
    streetInfo = null;
    System.gc();
    streetInfo = new StreetInfo(streetTSID); 
            
    // Now read the error flag for the street array added
    if (!streetInfo.readOkFlag())
    {
       printToFile.printDebugLine(this, "Error creating street data structure", 3);
       return false;
    }
        
    printToFile.printDebugLine(this, "Read street data for TSID " + streetTSID, 2);
            
    // Now populate the street information
    // Retrieves the G/L* JSON files and places them in OrigJSONs
    // Reads in the item array, reads in info from G* file and validates the snaps
    if (!streetInfo.initialiseStreetData())
    {
        printToFile.printDebugLine(this, "Error populating street data structure", 3);
        return false;
    }
                 
    // All OK
    return true;
}

boolean setupWorkingDirectories()
{
    // Checks that we have working directories for the JSONs - create them if they don't exist
    // If they exist - then empty them if not keeping the files becase debug option set   
    if (!Utils.setupDir(workingDir + File.separatorChar + "OrigJSONs", false))
    {
        printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
        return false;
    }
    
    // Default location for street output images is cleared each time the tool is run.
    // If the user has specified a path for these files, then they are not cleared - up to the user
    // Means that images are not lost when the tool is rerun for a single street for that region.
    if (!Utils.setupDir(workingDir + File.separatorChar +"StreetSummaries", false))
    {
        printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
        return false;
    }   
    return true; 
}


void keyPressed() 
{
    if ((key == 'x') || (key == 'X') || (key == 'q') || (key == 'Q'))
    {
        nextAction = EXIT_NOW;
        return;
    }
    
    // Make sure ESC closes window cleanly - and closes window
    if(key==27)
    {
        key = 0;
        nextAction = EXIT_NOW;
        return;
    }
}

boolean validConfigJSONLocation()
{
    // Searches for the configLocation.txt file which contains the saved location of the QAPlatlines_config.json file
    // That location is returned by this function.
    String  configLocation = "";
    File file = new File(sketchPath("configLocation.txt"));
    if (!file.exists())
    {
        return false;
    }
    
    // File exists - now validate
    //Read contents - first line is QAPlatlines_config.json location
    String [] configFileContents = loadStrings(sketchPath("configLocation.txt"));
    configLocation = configFileContents[0];
    
    // Have read in location - check it exists
    if (configLocation.length() > 0)
    {        
        file = new File(configLocation + File.separatorChar + "QAPlatlines_config.json");
        if (!file.exists())
        {
            println("Missing QAPlatlines_config.json file from ", configLocation);
            return false;
        }
    }
    workingDir = configLocation;  
    return true;
    
}

void configJSONFileSelected(File selection)
{
    if (selection == null) 
    {
        println("Window was closed or the user hit cancel");
        displayMgr.setSavedErrMsg("Window was closed or the user hit cancel");
        failNow = true;
        return;
    }      
    else 
    {
        println("User selected " + selection.getAbsolutePath());

        // Check that not selected QAPlatlines_config.json.txt which might look like QAPlatlines_config.json in the picker (as not seeing file suffixes for known file types on PC)
        if (!selection.getAbsolutePath().endsWith("QAPlatlines_config.json"))
        {
            println("Please select a QAPlatlines_config.json file (check does not have hidden .txt ending)");
            displayMgr.setSavedErrMsg("Please select a QAPlatlines_config.json file (check does not have hidden .txt ending)");
            failNow = true;
            return;
        }
        
        // User selected correct file name so now save
        String[] list = new String[1];
        // Strip out QAPlatlines_config.json part of name - to just get folder name
        list[0] = selection.getAbsolutePath().replace(File.separatorChar + "QAPlatlines_config.json", "");
        try
        {
            saveStrings(sketchPath("configLocation.txt"), list);
        }
        catch (Exception e)
        {
            println(e);
            println("error detected saving QAPlatlines_config.json location to configLocation.txt in program directory");
            displayMgr.setSavedErrMsg("Error detected saving QAPlatlines_config.json location to configLocation.txt in program directory");
            failNow = true;
            return;
        }
        workingDir = list[0];
    }
 
}
   
  public JSONObject loadJSONObjectFromFile(String filename)
  {    
      // Alternative to official loadJSONObject() which does not close the file after reading the JSON object
      // Which means subsequent file delete/remove fails
      // Only needed when reading files in NewJSONs i.e. when do the JSONDiff functionality
    File file = new File(filename);
    BufferedReader reader = createReader(file);
    JSONObject result = new JSONObject(reader);
    try
    {
        reader.close();
    }
    catch (IOException e) 
    {
        e.printStackTrace();
        println("I/O exception closing ");
        printToFile.printDebugLine(this, "I/O exception closing " + filename, 3);
        return null;
    }
    
    return result;

   }

   
   public boolean copyFile(String sourcePath, String destPath)
    {
        
        InputStream is = createInput(sourcePath);
        OutputStream os = createOutput(destPath);
        
        if (is == null || os == null)
        {
            // Error setting up streams.
            printToFile.printDebugLine(this, "Error setting up streams for " + sourcePath + " and/or " + destPath, 3);
            return false;
        }
        
        byte[] buf = new byte[1024];
        int len;
        try 
        {
            while ((len = is.read(buf)) > 0) 
            {
                os.write(buf, 0, len);
            }
            
        }
        catch (IOException e) 
        {
            e.printStackTrace();
            printToFile.printDebugLine(this, "I/O exception copying " + sourcePath + " to " + destPath, 3);
            return false;
        }
        finally 
        {
            try 
            {
                is.close();
                os.flush();
                os.close();

            } 
            catch (IOException e) 
            {
                e.printStackTrace();
                printToFile.printDebugLine(this, "I/O exception closing " + sourcePath + " and/or " + destPath, 3);
                return false;
            }
        }
        
        return true;
    }
    
    // This makes sure that if user clicks on 'x', the program shuts cleanly.
    // Handles all kinds of exit.
    private void prepareExitHandler () 
    {

        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

        public void run () 
        {

           //System.out.println("SHUTDOWN HOOK");

           // application exit code here
           //nextAction = EXIT_NOW;
           // Have to call the exit handling functionality directly
           doExitCleanUp();
        }

    }));
   
}