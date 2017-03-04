class PrintToFile 
{
   
   boolean okFlag; 
   StringList existingOutputText;
   
    // Save the start time so can report how long the scan took
    long startTimeMillis; 
    
     // constructor/initialise fields
    public PrintToFile()
    {
        okFlag = true;
        startTimeMillis = System.currentTimeMillis();
    }
    
    public boolean initPrintToDebugFile()
    { 
        // Open debug file
        debugOutput = new OutputFile(workingDir + File.separatorChar + "debug_info.txt", true);  
        
        // Open debug file
        if (debugLevel > 0)
        {
            // Collecting debug info so open file
            if (!debugOutput.openOutputFile())
            {
                return false;
            }
        } 
        // Print timestamp at top of file
        printDebugLine(this, getTimeStamp(), 3);             
        return true;
    }     
    
    public boolean initPrintToOutputFile()
    {   
        // Open output file
        infoOutput = new OutputFile(configInfo.readOutputFilename(), false);
        
        // If file already exists - then rename before creating this output file  
        if (!renameExistingFile(configInfo.readOutputFilename()))
        {
            return false;
        }

        // Now have saved any existing Output file contents, can open the output file ready for writing  
        if (!infoOutput.openOutputFile())
        {
            return false;
        }
        
        // Write header information - which just dumps out the settings in the QAPlatlines_config.json file 
        printOutputLine(getTimeStamp());      
        infoOutput.writeHeaderInfo();
        return true;
    } 
        
    boolean renameExistingFile(String existingFname)
    {
        // If the file already exists, then rename before continuing on
        
        File f = new File(existingFname);
        if (!f.exists())
        {
            // Does not exist - so OK to continue
            return true;
        }
        
        // Output file already exists. So rename
        String fileName = f.getName();
        String fileNamePrefix = fileName.replace(".txt", "");
        String fileDir = existingFname.replace(File.separatorChar + fileName, "");
        String [] files = Utils.loadFilenames(fileDir, fileNamePrefix, ".txt");
        if (files.length == 0)
        {
            println("Unexpected error setting up file " + existingFname + " - please remove all versions of the file before retrying");
            displayMgr.showErrMsg("Unexpected error setting up file " + existingFname + " - please remove all versions of the file before retrying", true);
            return false;
        }

        // If outputFile is the only one that exists, then will be renamed to _1 etc etc. 
        // This will fail if the user has manually changed the numbers so e.g. get outputFile and outputFile_2 being present - 
        // the attempt to rename outputFile to outputFile_2 will fail. But this is the simplest way of renaming a file
        // because the loadFilenames function returns files in alphabetical order so outputFile22 is earlier in the list than 
        // outputFile_8 ... 
        String destFilename = fileDir + File.separatorChar + fileNamePrefix + "_" + files.length + ".txt";
        File destFile = new File(destFilename);
        try
        {
            if (!f.renameTo(destFile))
            {
                println("Error attempting to move " + existingFname + " to ", destFilename + " - please remove all versions of the file before retrying");
                displayMgr.showErrMsg("Error attempting to move " + existingFname + " to " + destFilename + " - please remove all versions of the file before retrying", true);
                return false;
            }
        }
        catch (Exception e)
        {
             // if any error occurs
             e.printStackTrace();  
             println("Error attempting to move " + existingFname + " to " + destFilename + " - please remove all versions of the file before retrying");
             displayMgr.showErrMsg("Error attempting to move " + existingFname + " to " + destFilename + " - please remove all versions of the file before retrying", true);
             return false;
        }
        
        println("Moving " + existingFname + " to " + destFilename);
        displayMgr.showInfoMsg("Moving " + existingFname + " to " + destFilename);
        return true;
    }
 
    // Used to just print debug information - so can filter out minor messages
    // if not needed
    public void printDebugLine(Object callingClass, String lineToWrite, int severity)
    {     
        // Do nothing if not collecting debug info
        if (debugLevel == 0)
        {
            return;
        }
        
        if (severity >= debugLevel)
        {
            String s = callingClass.getClass().getName().replace("QAPlatlineChecker$", " ") + "::";
            String methodName = Thread.currentThread().getStackTrace()[2].getMethodName();
            
            // Do we need to print this line to the console
            if (debugToConsole)
            {
                println(s + lineToWrite);
            }
        
            // Output line 
            debugOutput.printLine(s + methodName + ":\t" + lineToWrite);
        }
    }
    
    // prints out line to file which tells the user what the tool actually did/found
    public void printOutputLine(String lineToWrite)
    {
               
        // Do we need to print this line to the console
        if (debugToConsole)
        {
            println(lineToWrite);
        }
        
        // Output line 
        infoOutput.printLine(lineToWrite);
    }
    
    public void closeOutputFile()
    {
        if (infoOutput != null)
        {
            infoOutput.closeFile();
        }
        return;
    }
    
    public void closeDebugFile()
    {
        if (debugOutput != null)
        {
            debugOutput.closeFile();
        }
        return;
    }
        
    public void printSummaryHeader()
    {
        infoOutput.writeStreetHeaderInfo();
        return; 
    }
    
    public String getTimeStamp()
    {
        String timeStamp;
        timeStamp = nf(day(),2) + "/" + nf(month(),2) + "/" + year() + "   " + nf(hour(),2) + ":" + nf(minute(),2) + ":" + nf(second(),2);
        return timeStamp;
    }
    
    public boolean printOutputSummaryData(ArrayList<SummaryChanges> itemResults)
    {
        if (!infoOutput.printSummaryData(itemResults))
        {
            return false;
        }

        return true;
    }   
          
    public boolean readOkFlag()
    {
        return (okFlag);
    }
    
    public String scanDuration()
    {
        String str = "";
        long scanLengthMillis = System.currentTimeMillis() - startTimeMillis;
        long remainder;
        long value;
        // Now convert to hours, mins, secs and format as nice string
        value = scanLengthMillis/(60*60*1000);
        if (value > 0)
        {
            str = str + value + " hours";
        }
        remainder = scanLengthMillis - (value * 60*60*1000);
        value = remainder/(60*1000);
        if (value > 0)
        {
            if (str.length() > 0)
            {
                str = str + " ";
            }
            str = str + value + " mins";
        }
        remainder = remainder - (value*60*1000);    
        value = remainder/1000;
        if (value > 0)
        {
            if (str.length() > 0)
            {
                str = str + " ";
            }
            str = str + value + " secs";
        }
        return(str);
    }
    
}