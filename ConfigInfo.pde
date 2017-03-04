class ConfigInfo {
    
    boolean okFlag;
    
    boolean useVagrant;
    String elevenPath;
    String fixturesPath;
    String persdataPath;

    String serverName;
    String serverUsername;
    String serverPassword;
    int serverPort;
    
    String outputStreetImagesPath;
        
    StringList streetTSIDs = new StringList();
    String outputFile;

    // constructor/initialise fields
    public ConfigInfo()
    {
        okFlag = true;
            
        // Read in config info from JSON file
        if (!readConfigData())
        {
            println("Error in readConfigData");
            // displayMgr.showErrMsg("Error in readConfigData", true); - not do this as overwrites the information given by readConfigData call to this function
            okFlag = false;
            return;
        }      
    }
    
    boolean readConfigData()
    {
        JSONObject json;
        File myDir;
        File file;
        
        // Open the config file
        file = new File(workingDir + File.separatorChar + "QAPlatlines_config.json");
        if (!file.exists())
        {
            println("Missing QAPlatlines_config.json file from ", workingDir);
            displayMgr.showErrMsg("Missing QAPlatlines_config.json file from " + workingDir, true);
            return false;
        }
        else
        {
            println("Using QAPlatlines_config.json file in ", workingDir);
            printToFile.printDebugLine(this, "Using QAPlatlines_config.json file in " + workingDir, 1);
        }
        
        try
        {
            // Read in stuff from the config file
            json = loadJSONObject(workingDir + File.separatorChar + "QAPlatlines_config.json"); 
        }
        catch(Exception e)
        {
            println(e);
            println("Failed to load QAPlatlines_config.json file - check file is correctly formatted by pasting contents into http://jsonlint.com/");
            displayMgr.showErrMsg("Failed to load QAPlatlines_config.json file - check file is correctly formatted by pasting contents into http://jsonlint.com/", true);
            return false;
        }
               
        // Now read in the different fields
        useVagrant = Utils.readJSONBool(json, "use_vagrant_dirs", true);  
        if (!Utils.readOkFlag())
        {
            println(Utils.readErrMsg());
            println("Failed to read use_vagrant_dirs in QAPlatlines_config.json file");
            displayMgr.showErrMsg("Failed to read use_vagrant_dirs in QAPlatlines_config.json file", true);
            return false;
        }
        
        // Read in the locations of the JSON directories        
        JSONObject fileSystemInfo;
        if (useVagrant)
        {
            fileSystemInfo = Utils.readJSONObject(json, "vagrant_dirs", true);
            if (!Utils.readOkFlag())
            {
                println(Utils.readErrMsg());
                println("Failed to read vagrant_info in QAPlatlines_config.json file");
                displayMgr.showErrMsg("Failed to read vagrant_info in QAPlatlines_config.json file", true);
                return false;
            }           
            serverName = "";
            serverUsername = "";
            serverPassword = "";
            serverPort = 0;
            uploadString = "Copying";
            downloadString = "Copying";
        }
        else
        {
            // Read in server details
            JSONObject serverInfo = Utils.readJSONObject(json, "server_info", true); 
            if (!Utils.readOkFlag())
            {
                println(Utils.readErrMsg());
                println("Failed to read server_info in QAPlatlines_config.json file");
                displayMgr.showErrMsg("Failed to read server_info in QAPlatlines_config.json file", true);
                return false;
            }  
            serverName = Utils.readJSONString(serverInfo, "host", true);
            if (!Utils.readOkFlag())
            {
                println(Utils.readErrMsg());
                println("Failed to read server host name in QAPlatlines_config.json file");
                displayMgr.showErrMsg("Failed to read server host name in QAPlatlines_config.json file", true);
                return false;
            }  
            serverUsername = Utils.readJSONString(serverInfo, "username", true);
            if (!Utils.readOkFlag())
            {
                 println(Utils.readErrMsg());
                 println("Failed to read server username in QAPlatlines_config.json file");
                 displayMgr.showErrMsg("Failed to read server username in QAPlatlines_config.json file", true);
                 return false;
            }            
            serverPassword = Utils.readJSONString(serverInfo, "password", true);
            if (!Utils.readOkFlag())
            {
               println(Utils.readErrMsg());
               println("Failed to read server password in QAPlatlines_config.json file");
               displayMgr.showErrMsg("Failed to read server password in QAPlatlines_config.json file", true);
               return false;
            }
            serverPort = Utils.readJSONInt(serverInfo, "port", true);
            if (!Utils.readOkFlag())
            {
               println(Utils.readErrMsg());
               println("Failed to read port in QAPlatlines_config.json file");
               displayMgr.showErrMsg("Failed to read port in QAPlatlines_config.json file", true);
               return false;
            }
            
            fileSystemInfo = Utils.readJSONObject(serverInfo, "server_dirs", true);
            if (!Utils.readOkFlag())
            {
                println(Utils.readErrMsg());
                println("Failed to read server_dirs in QAPlatlines_config.json file");
                displayMgr.showErrMsg("Failed to read server_dirs in QAPlatlines_config.json file", true);
                return false;
            }
            uploadString = "Uploading";
            downloadString = "Downloading";
        }
        
        // Now read in the appropriate dirs that contain JSON files
        elevenPath = Utils.readJSONString(fileSystemInfo, "eleven_path", true); 
        if (!Utils.readOkFlag() || elevenPath.length() == 0)
        {
            println(Utils.readErrMsg());
            if (useVagrant)
            {
                println("Failed to read eleven_path from vagrant_dirs in QAPlatlines_config.json file");
                displayMgr.showErrMsg("Failed to read eleven_path from vagrant_dirs in QAPlatlines_config.json file", true);
            }
            else
            {
                println("Failed to read eleven_path from server_dirs in QAPlatlines_config.json file");
                displayMgr.showErrMsg("Failed to read eleven_path from server_dirs in QAPlatlines_config.json file", true);
            }
            return false;
        }
        
        // Just in case someone has non-standard paths
        // If this is present, then use it, otherwise construct the paths
        fixturesPath = Utils.readJSONString(fileSystemInfo, "fixtures_path", false);
        if (fixturesPath.length() == 0)
        {
            // Use default path
            if (useVagrant)
            {
                fixturesPath = elevenPath + File.separatorChar + "eleven-fixtures-json";
            }
            else
            {
                fixturesPath = elevenPath + "/eleven-fixtures-json";
            }
        }
        persdataPath = Utils.readJSONString(fileSystemInfo, "persdata_path", false);
        if (persdataPath.length() == 0)
        {
            // Use default path
            if (useVagrant)
            {
                persdataPath = elevenPath + File.separatorChar + "eleven-throwaway-server" + File.separatorChar + "persdata";
            }
            else
            {
                persdataPath = elevenPath + "/eleven-throwaway-server/persdata";
            }
        }
                
        // Check that the directories exist
        if (useVagrant)
        {
            myDir = new File(fixturesPath);
            if (!myDir.exists())
            {
                println("Fixtures directory ", fixturesPath, " does not exist");
                displayMgr.showErrMsg("Fixtures directory " + fixturesPath + " does not exist", true);
                return false;
            }
            myDir = new File(persdataPath);
            if (!myDir.exists())
            {
                println("Persdata directory ", persdataPath, " does not exist");
                displayMgr.showErrMsg("Persdata directory " + persdataPath + " does not exist", true);
                return false;
            }            
        }
        else
        {
            // Will validate the fixtures/persdata/persdata-qa paths on server once session has been established
        }
       
        // This directory will contain any street images generated by the tool - if it is not specified then 
        // images will be placed in the working directory - but will be cleared the next time the tool is run    
        outputStreetImagesPath = Utils.readJSONString(json, "output_street_images_path", false);
        if (outputStreetImagesPath.length() == 0)
        {
            println("Failed to read output_street_images_path in QAPlatlines_config.json file - using default " + workingDir + File.separatorChar + "StreetSummaries");
            // Don't report as error as would confuse the user - can't dump to log file as not yet created
            //displayMgr.showErrMsg("Failed to read output_street_images_path in QAPlatlines_config.json file - using default " + defaultOutputStreetImagePath, false);
            // Set path to the default
            outputStreetImagesPath = workingDir + File.separatorChar + "StreetSummaries";           
        }

        myDir = new File(outputStreetImagesPath);
        if (!myDir.exists())
        {
            // Directory dos not exist - so create it
            println("output_street_images_path directory ", outputStreetImagesPath, " does not exist");
            // create directory
            try
            {
                myDir.mkdir();
            }
            catch(Exception e)
            {
                println(e);
                println("Failed to create " + outputStreetImagesPath + " directory");
                displayMgr.showErrMsg("Failed to create " + outputStreetImagesPath + " directory", true);
                return false;
            } 
            // Successfully created firectory
            println("Successfully created " + outputStreetImagesPath + " directory");
        }
               
        outputFile = Utils.readJSONString(json, "output_file", true);
        if (!Utils.readOkFlag() || outputFile.length() == 0)
        {
            println(Utils.readErrMsg());
            println("Failed to read output_file in QAPlatlines_config.json file");
            displayMgr.showErrMsg("Failed to read output_file in QAPlatlines_config.json file", true);
            return false;
        }        
        // Need to check that output file is a text file
        if (outputFile.indexOf(".txt") == -1)
        {
            println("Output file (output_file) needs to be a .txt file");
            displayMgr.showErrMsg("Output file (output_file) needs to be a .txt file", true);
            return false;
        } 
        
        debugLevel = Utils.readJSONInt(json, "tracing_level", false);
        if (!Utils.readOkFlag())
        {
            debugLevel = 1;
        }
        else if ((debugLevel < 0) || (debugLevel > 3))
        {
            println("Please enter a valid value for tracing_level which is between 0-3 (0 is off, 1 gives much information, 3 reports errors only) in QAPlatlines_config.json file");
            displayMgr.showErrMsg("Please enter a valid value for tracing_level which is between 0-3 (0 is off, 1 gives much information, 3 reports errors only) in QAPlatlines_config.json file", true);
            return false;
        }
        
        // Read in array of street TSID from config file
        JSONArray TSIDArray;
        TSIDArray = Utils.readJSONArray(json, "streets", true);

        if (!Utils.readOkFlag())
        {
            println(Utils.readErrMsg());
            println("Failed to read in streets array from QAPlatlines_config.json");
            displayMgr.showErrMsg("Failed to read in streets array from QAPlatlines_config.json", true);
            return false;
        }
        try
        {
            for (int i = 0; i < TSIDArray.size(); i++)
            {    
                // extract the TSID
                JSONObject tsidObject = Utils.readJSONObjectFromJSONArray(TSIDArray, i, true);
                if (!Utils.readOkFlag())
                {
                    println(Utils.readErrMsg());
                    println("Unable to read TSID entry from streets array in QAPlatlines_config.json");
                    displayMgr.showErrMsg("Unable to read TSID entry from streets array in QAPlatlines_config.json", true);
                    return false;
                }
                             
                String tsid = Utils.readJSONString(tsidObject, "tsid", true);
                if (!Utils.readOkFlag() || tsid.length() == 0)
                {
                    println(Utils.readErrMsg());
                    println("Missing value for street tsid");
                    displayMgr.showErrMsg("Missing value for street tsid", true);
                    return false;
                }
                streetTSIDs.append(tsid);
            }
        }
        catch(Exception e)
        {
            println(e);
            println("Failed to read (exception) in street array from QAPlatlines_config.json");
            displayMgr.showErrMsg("Failed to read (exception) in street array from QAPlatlines_config.json", true);
            return false;
        }  
        
            
        // Everything OK
        return true;
    }
           
    public boolean readOkFlag()
    {
        return okFlag;
    }
    
    public boolean readUseVagrantFlag()
    {
        return useVagrant;
    }   
    
    public String readFixturesPath()
    {
        return fixturesPath;
    }
       
    public String readPersdataPath()
    {
        return persdataPath;
    } 
         
    public String readStreetTSID(int n)
    {
        if (n < streetTSIDs.size())
        {
            return streetTSIDs.get(n);
        }
        else
        {
            // error condition
            return "";
        }
    }
    
    public int readTotalJSONStreetCount()
    {
        return streetTSIDs.size();
    }
    
    public String readOutputFilename()
    {
        return outputFile;
    } 
    
    public String readServerName()
    {
        return serverName;
    }
    
    public String readServerUsername()
    {
        return serverUsername;
    }
    
    public String readServerPassword()
    {
        return serverPassword;
    }
    public int readServerPort()
    {
        return serverPort;
    }
        
    public String readElevenPath()
    {
        return elevenPath;
    }
    
    public String readOutputStreetImagesPath()
    {
        return outputStreetImagesPath;
    }    
}