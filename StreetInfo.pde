import java.nio.file.Path;
import java.util.Collections;
import java.util.List;
import processing.data.JSONObject;

class StreetInfo
{
    boolean okFlag;
    boolean streetInitialisationFinished;
    boolean invalidStreet;
    boolean skipStreet;
    
    // passed to constructor - read in originally from QAPlatlines_config.json
    String streetTSID;
    
    // Read in from L* file
    JSONArray streetItems;
    String streetName;
    String hubID;
          
    // List of item results - so can sort 
    ArrayList<SummaryChanges> itemResults;  
    
    // List of plat lines on street - so can sort
    ArrayList<Platline> platlines;  
    
    // Data read in from each I* file
    int itemBeingProcessed;
    ArrayList<ItemInfo> itemInfo;
      
    // Data read in from G* which is used elsewhere in class
    int geoHeight;
    int geoWidth;
    
    PImage summaryStreetSnap;
    
    boolean usingBlankStreet;
    
    final static int STREET_BACKGROUND = #BFBFBF; // grey
    //final static int STREET_BACKGROUND = #FFFFFF; // white
    //final static int PLATLINE_COLOUR =  #5CFF00; // green
    final static int PLATLINE_COLOUR =  #FF0000; // red
    //final static int BOX_COLOUR = #000000; // black
    final static int BOX_COLOUR = #952FEA; // same colour as spice tree
    
    // See sketch_reshade_spice_tree for actual values used
    final static int SPICE_TREE = #952FEA;
    final static int SPICE_TREE_ROOTS = #B98DDE;
    
     
    // constructor/initialise fields
    public StreetInfo(String tsid)
    {
        okFlag = true;
        
        if (tsid.length() == 0)
        {
            printToFile.printDebugLine(this, "Null street tsid passed to StreetInfo structure - entry " + streetBeingProcessed, 3);
            okFlag = false;
            return;
        }
        
        itemBeingProcessed = 0;
        invalidStreet = false;
        skipStreet = false;
        streetInitialisationFinished = false;

        streetTSID = tsid;       
        itemInfo = new ArrayList<ItemInfo>();
        itemResults = new ArrayList<SummaryChanges>();
        platlines = new ArrayList<Platline> ();  
         
        geoHeight = 0;
        geoWidth = 0;
        
        summaryStreetSnap = null;
        
        usingBlankStreet = false;
    }
    
    boolean readStreetData()
    {
        // Now read in item list and street from L* file - use the version which has been downloaded/copied to OrigJSONs
        String locFileName = workingDir + File.separatorChar + "OrigJSONs" + File.separatorChar+ streetTSID + ".json";
     
        // First check L* file exists - 
        File file = new File(locFileName);
        if (!file.exists())
        {
            // Should never happen - as error would have been reported/handled earlier - so only get here if the file was copied/downloaded OK
            printToFile.printDebugLine(this, "Fail to find street JSON file " + locFileName, 3);
            return false;
        } 
                
        JSONObject json;
        try
        {
            // load L* file
            json = loadJSONObject(locFileName);
        }
        catch(Exception e)
        {
            println(e);
            printToFile.printDebugLine(this, "Fail to load street JSON file " + locFileName, 3);
            return false;
        } 
        printToFile.printDebugLine(this, "Reading location file " + locFileName, 2);
        
        // Read in street name
                
        streetName = Utils.readJSONString(json, "label", true);
        if (!Utils.readOkFlag() || streetName.length() == 0)
        {
            printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
            printToFile.printDebugLine(this, "Fail to read in street name from street JSON file " + locFileName, 3);
            return false;
        }
  
        printToFile.printDebugLine(this, "Street name is " + streetName, 2);
        
        // Read in the region id
        hubID = Utils.readJSONString(json, "hubid", true);
        if (!Utils.readOkFlag() || hubID.length() == 0)
        {
            printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
            printToFile.printDebugLine(this, "Fail to read in hub id from street JSON file " + locFileName, 3);
            return false;
        }
        
        printToFile.printDebugLine(this, "Region/hub id is " + hubID, 2);
    
        // Read in the list of street items
        streetItems = Utils.readJSONArray(json, "items", true);
        if (!Utils.readOkFlag())
        {
            printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
            printToFile.printDebugLine(this, "Fail to read in item array in street JSON file " + locFileName, 3);
            return false;
        } 
 
         // Everything OK   
        return true;
    }
       
    boolean readStreetItemData()
    {
        String itemTSID = readCurrentItemTSIDBeingProcessed();
        if (itemTSID.length() == 0)
        {
            return false;
        }
        
        printToFile.printDebugLine(this, "Read item TSID " + itemTSID + " from street L file " + streetTSID, 2);  
        
        // First download/copy the I* file
        if (!getJSONFile(itemTSID))
        {
            // This is treated as an error - if the connection is down, no point continuing
            // whereas a missing L* file is not an error as could be due to a type in the list
            printToFile.printDebugLine(this, "ABORTING: Failed to copy/download item JSON file " + itemTSID + ".json" + " on " + streetName, 3);
            printToFile.printOutputLine("ABORTING: Failed to copy/download item JSON file " + itemTSID + ".json" + " on " + streetName);
            displayMgr.showErrMsg("Failed to copy/download item JSON file " + itemTSID + ".json" + " on " + streetName, true);
            return false;
        }
                       
        // First set up basic information for this item - i.e. item TSID
        JSONObject thisItem = Utils.readJSONObjectFromJSONArray(streetItems, itemBeingProcessed, true); 
        if (!Utils.readOkFlag())
        {
            printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
            return false;
        }
        itemInfo.add(new ItemInfo(thisItem)); 
        
        int index = itemInfo.size() - 1;
        
        // Check error flag for this entry that has just been added
        ItemInfo itemData = itemInfo.get(index);     
        if (!itemData.readOkFlag())
        {
           printToFile.printDebugLine(this, "Error parsing item basic TSID information for item " + itemTSID, 3);
           displayMgr.showErrMsg("Error parsing item basic TSID information for item " + itemTSID, true);
           return false;
        }
        
        // Now fill in rest of information from this JSON file
        if (!itemInfo.get(index).initialiseItemInfo())
        {
            // actual error
            printToFile.printDebugLine(this, "Error initialising rest of information for " + itemTSID, 3);
            displayMgr.showErrMsg("Error initialising rest of information for " + itemTSID, true);
            return false;
        }
        
        // Everything OK - so set up ready for next item
        itemBeingProcessed++;
        if (itemBeingProcessed >= streetItems.size())
        {
            // Gone past end of items so now ready to start proper processing - finished loading up street and all item files on this street
            printToFile.printDebugLine(this, " Initialised street = " + streetName + " street TSID = " + streetTSID + " with item count " + str(itemInfo.size()), 2);
            
            // Reset everything ready
            itemBeingProcessed = 0;
            
            // Inform the top level that now OK to move on to street processing
            streetInitialisationFinished = true;
        }

        return true;
    }
    
    boolean readStreetGeoInfo()
    {       
        // Now read in information about size/platlines etc from the G* file if it exists - should have been downloaded to OrigJSONs dir
        String geoFileName = workingDir + File.separatorChar + "OrigJSONs" + File.separatorChar + streetTSID.replaceFirst("L", "G") + ".json";  
        
        // First check G* file exists
        File file = new File(geoFileName);
        if (!file.exists())
        {
            // Error - as already handled the case if file not downloaded OK to OrigJSONs dir
            printToFile.printDebugLine(this, "Failed to find geo JSON file " + geoFileName, 3);
            return false;
        } 
                
        JSONObject json;
        try
        {
            // load G* file
            json = loadJSONObject(geoFileName);
        }
        catch(Exception e)
        {
            println(e);
            printToFile.printDebugLine(this, "Fail to load street geo JSON file " + geoFileName, 3);
            return false;
        } 
        printToFile.printDebugLine(this, "Reading geo file " + geoFileName, 2);

        // Now chain down to get at the fields in the geo file               
        JSONObject dynamic = Utils.readJSONObject(json, "dynamic", false);
        if (!Utils.readOkFlag() || dynamic == null)
        {
            // the dynamic level is sometimes missing ... so just set it to point at the original json object and continue on
            printToFile.printDebugLine(this, "Reading geo file - failed to read dynamic key, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 2);
            if (dynamic == null)
            {
                printToFile.printDebugLine(this, "Reading geo file - dynamic is null " + geoFileName, 2);
            }
            dynamic = json;
            if (dynamic == null)
            {
                // This should never happen as json should not be null at this point
                printToFile.printDebugLine(this, "Reading geo file - unexpected error as reset dynamic pointer is null " + geoFileName, 3);
                return false;
            }
        }
        
        // So are either reading layers from the dynamic or higher level json objects, depending on whether dynamic had been found
        JSONObject layers = Utils.readJSONObject(dynamic, "layers", true);
        
        // Also need to sort plat lines so that have a list in order low x -> highx, 
        
        if (Utils.readOkFlag() && layers != null)
        {
            JSONObject middleground = Utils.readJSONObject(layers, "middleground", true);
            if (Utils.readOkFlag() && middleground != null)
            {
                 geoWidth = Utils.readJSONInt(middleground, "w", true);
                if (!Utils.readOkFlag() || geoWidth == 0)
                {
                    printToFile.printDebugLine(this, "Failed to read width of street from geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                    return false;
                }
                geoHeight = Utils.readJSONInt(middleground, "h", true);
                if (!Utils.readOkFlag() || geoHeight == 0)
                {
                    printToFile.printDebugLine(this, "Failed to read height of street from geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                    return false;
                }
                printToFile.printDebugLine(this, "Geo JSON file " + geoFileName + " gives street snap height " + geoHeight + " snap width " + geoWidth, 1);

                // Read in the platform_lines object which contains all of the plat lines
                JSONObject platform_lines = Utils.readJSONObject(middleground, "platform_lines", true);
                if (Utils.readOkFlag() && platform_lines != null)
                {
                    if (!readPlatlineInfo(platform_lines, geoFileName))
                    {
                        // Error message already logged by function
                        return false;
                    }
                }
                else
                {
                    printToFile.printDebugLine(this, "Failed to read platform_lines from geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                    return false;
                }
            } // if middleground not null
            else
            {
                // This counts as an error as need the snap size from the file
                 printToFile.printDebugLine(this, "Reading geo file - failed to read middleground, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                 return false;
            }
         } // layers not null
         else
         {
             // Failed to read the layers structure from geo file - which means we don't have the snap size from the file - so counts as error
             printToFile.printDebugLine(this, "Reading geo file - failed to read layers, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
             return false;
         }
          
         // Everything OK 
        return true;
    }
    
    boolean readPlatlineInfo(JSONObject platformLinesObject, String geoFileName)
    {
        int i;
        String platKey;
        // Now need to chain down through this object, extracting the x,y pairs from each 
        // As we don't know the string for each platline name, need to do it this clunky way                   
        List<String> platlineList = new ArrayList(platformLinesObject.keys());
        printToFile.printDebugLine(this, "Reading geo file - number of plat lines is " + platlineList.size(), 2);
                    
        for (i = 0; i < platlineList.size(); i++)
        {
            JSONObject platLineObj = Utils.readJSONObject(platformLinesObject, platlineList.get(i), true);
            if (Utils.readOkFlag() && platLineObj != null)
            {
                platKey = platlineList.get(i);
                JSONObject startObj = Utils.readJSONObject(platLineObj, "start", true);
                if (Utils.readOkFlag() && startObj != null)
                {
                    JSONObject endObj = Utils.readJSONObject(platLineObj, "end", true);
                    if (Utils.readOkFlag() && endObj != null)
                    {
                        int x1 = Utils.readJSONInt(startObj, "x", true);
                        if (Utils.readOkFlag())
                        {
                            int y1 = Utils.readJSONInt(startObj, "y", true);
                            if (Utils.readOkFlag())
                            {
                                int x2 = Utils.readJSONInt(endObj, "x", true);
                                if (Utils.readOkFlag())
                                {
                                    int y2 = Utils.readJSONInt(endObj, "y", true); 
                                    if (Utils.readOkFlag())
                                    {
                                        // Add the pair of co-ordinates to list
                                        platlines.add(new Platline(platKey, x1, y1, x2, y2));
                                    }
                                    else
                                    {
                                        printToFile.printDebugLine(this, "Failed to read y from end object, platline number " + str(i+1) + " from platform_lines object in geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                                        return false; 
                                    }
                                }
                                else
                                {
                                    printToFile.printDebugLine(this, "Failed to read x from end object, platline number " + str(i+1) + " from platform_lines object in geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                                    return false; 
                                }
                            }
                            else
                            {
                                printToFile.printDebugLine(this, "Failed to read y from start object, platline number " + str(i+1) + " from platform_lines object in geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                                return false; 
                            }
                        }
                        else
                        {
                            printToFile.printDebugLine(this, "Failed to read x from start object, platline number " + str(i+1) + " from platform_lines object in geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                            return false; 
                        }
                    }
                    else
                    {
                        printToFile.printDebugLine(this, "Failed to read end object, platline number " + str(i+1) + " from platform_lines object in geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                        return false; 
                    }
                 }
                 else
                 {
                     printToFile.printDebugLine(this, "Failed to read start object, platline number " + str(i+1) + " from platform_lines object in geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                     return false; 
                 }
             }
             else
             {
                 printToFile.printDebugLine(this, "Failed to read platline number " + str(i+1) + " from platform_lines object in geo JSON file, err msg ='" + Utils.readErrMsg() + "' " +  geoFileName, 3);
                 return false;    
             }
         }
                    
         printToFile.printDebugLine(this, "Reading geo file - size of platlines list is " + platlines.size(), 1);  
         for (i = 0; i < platlines.size(); i++)
         { 
             printToFile.printDebugLine(this, "Reading geo file - platlines start x:y " + platlines.get(i).readStartX() + ":" + platlines.get(i).readStartY() + " end x:y " + platlines.get(i).readEndX() + ":" + platlines.get(i).readEndY(), 1);
         }            
        return true;
    }
    
    public boolean initialiseStreetData()
    {
        // Need to retrieve the G*/L* files from vagrant/server and copy to OrigJSONs directory
        if (!getJSONFile(streetTSID))
        {
            // Unable to get the L* JSON file
            // This isn't treated as an error - could have been a typo in the TSID list
            printToFile.printDebugLine(this, "Failed to copy/download street L* JSON file so SKIPPING STREET " + streetTSID, 3);
            printToFile.printOutputLine("============================================================================================\n");
            printToFile.printOutputLine("Failed to copy/download street L* JSON file so SKIPPING STREET " + streetTSID + "\n");
            displayMgr.setSkippedStreetsMsg("Skipping street: Failed to copy/download loc file " + streetTSID + ".json");
            invalidStreet = true;
            return true; // continue
        }
        
        // Read in street data - list of item TSIDs 
        // As this also reads in the street name, done here so that we can output that information if we skip the street because no G* file or in persdata-qa
        if (!readStreetData())  //<>//
        {
            // error - need to stop //<>//
            printToFile.printDebugLine(this, "Error in readStreetData", 3);
            okFlag = false;
            return false;
        } 
                
        if (!getJSONFile(streetTSID.replaceFirst("L", "G")))
        {
            // Unable to get the G* JSON file
            printToFile.printDebugLine(this, "Failed to copy/download street G* JSON file so SKIPPING STREET " + streetTSID + "(" + streetName + ")", 3);
            printToFile.printOutputLine("============================================================================================\n");
            printToFile.printOutputLine("Failed to copy/download street G* JSON file so SKIPPING STREET " + streetTSID + "(" + streetName + ")\n");
            displayMgr.setSkippedStreetsMsg("Skipping street: Failed to copy/download geo file " + streetTSID.replaceFirst("L", "G") + ".json" + "(" + streetName + ")");
            invalidStreet = true;
            return true; // continue
        }       
 //<>//
        // If street does not contain any items then continue to next street
        if (streetItems.size() <= 0)
        {
            // This isn't treated as an error - but don't want to carry on with this street as it doesn't contain anything that can be handled
            printToFile.printDebugLine(this, "SKIPPING STREET because " + streetTSID + "(" + streetName + ") does not contain any items which can be QA'd by this tool", 3);
            printToFile.printOutputLine("============================================================================================\n");
            printToFile.printOutputLine("SKIPPING STREET because " + streetTSID + "(" + streetName + ") does not contain any items which can be QA'd by this tool\n");
            displayMgr.setSkippedStreetsMsg("SKIPPING STREET because " + streetTSID + "(" + streetName + ") does not contain any items which can be QA'd by this tool");
            skipStreet = true;
            return true; // continue
        }

        // Display message giving street name across top of screen
        displayMgr.setStreetName(streetName, streetTSID, streetBeingProcessed + 1, configInfo.readTotalJSONStreetCount());
        displayMgr.showStreetName();
        displayMgr.showStreetProcessingMsg();
        
        // Read in the G* file and load up the contrast settings etc (currently not used as searching on black/white)
        if (!readStreetGeoInfo())
        {
            // error - need to stop
            printToFile.printDebugLine(this, "Error in readStreetGeoInfo", 3);
            okFlag = false;
            return false;
        }
                
        // Now get ready to start uploading the first item
        itemBeingProcessed = 0;
       
        return true;
    }
    
    public boolean processStreet()
    {
        int i;
        
        // First load up the street image or a blank street (if no snaps directory supplied)
        if (configInfo.readStreetSnapPath().length() == 0)
        {
            // Create blank street image
            createBlankStreetImage();            
        }
        else
        {    
            // Copy from the first street image found - if a problem is encountered, then a blank street will be created
            createStreetImage();
        }
        
        // Draw on tree
        // Cycle through all items - if it is a tree then put spice tree at appropriate x,y
        for (i = 0; i < itemInfo.size(); i++) 
        {
            if (!itemInfo.get(i).readSkipThisItem())
            {
                // Item is patch/tree - so put image of spice tree at this x,y
                addSpiceTreeImage(itemInfo.get(i).readItemX(), itemInfo.get(i).readItemY());
            }
        }
        summaryStreetSnap.updatePixels();
      
        // Draw on the plat lines
        for (i = 0; i < platlines.size(); i++)
        {
            platlines.get(i).drawAliasedLine(summaryStreetSnap, PLATLINE_COLOUR);
        } 
        // Update pixels
        summaryStreetSnap.updatePixels();
        
        // Now need to identify all the trees which had platlines crossing
        // We know which platlines crossed tree roots - but isn't much use now. 
        // Inefficient - but simplest way is look at all the spice tree pixels again - if they don't match the original, then must have been overwritten
        // with a plat line
        
        // Cycle through all items - check each tree location
        for (i = 0; i < itemInfo.size(); i++) 
        {
            boolean treeCrossesPlatline = false;
            if (!itemInfo.get(i).readSkipThisItem())
            {
                // Item is patch/tree - so put image of spice tree at this x,y
                treeCrossesPlatline = platlineCrossesSpiceTreeImage(itemInfo.get(i).readItemX(), itemInfo.get(i).readItemY());
                
                // If the platline has crossed the tree, then draw a box around the tree to draw attention to this fact
                if (treeCrossesPlatline)
                {
                    drawBox(itemInfo.get(i).readItemX(), itemInfo.get(i).readItemY());
                    printToFile.printDebugLine(this, "Drawing box around " + itemInfo.get(i).readItemTSID() + " " + itemInfo.get(i).readItemX() + "," + itemInfo.get(i).readItemY(), 1);
                }
            }
            // Store the result - will include details of whether tree crosses the plat line or not
            itemResults.add(new SummaryChanges(itemInfo.get(i), treeCrossesPlatline));
        }
        
        // Save file
        if (!saveStreetImage())
        {
            failNow = true;
            return false;
        }
        
        // Output results into log file
        if (!logResultsToFile())
        {
            failNow = true;
            return false;
        }
        
        // Display completed street on screen
        displayMgr.showStreetImage(summaryStreetSnap, streetName);
        return true;
        
    }
         
    boolean logResultsToFile()
    {
       // First need to write all the item changes to file      
       // As working on street that has already gone through QA and we're only reporting on trees, don't need to do anything more than a simple x,y sort
       printToFile.printSummaryHeader();
       Collections.sort(itemResults);
 
       // Now print out the summary array
       // Any actual errors are reported from within printOutputSummaryData
       if (!printToFile.printOutputSummaryData(itemResults))
       {
           failNow = true;
           return false;
       }
       
       return true;
    }
    
    void addSpiceTreeImage(int x, int y)
    {
        // Add the spice tree image
        // For spice tree the matching fragment is at 126, 170 in the trant_spice_10_complete image, and has width 63, height 23, offset -34, -62
        
        // Need to convert the tree x,y to snap x,y
        int treeX = x + geoWidth/2;
        int treeY = y + geoHeight; 
        
        int topX = treeX - 34 - 126;
        int topY = treeY - 62 - 170;
        
        float aSpiceTree;
        int loc;
        int streetLoc;
        
        // Point to the correct spice tree image depending on the street background
        PImage spiceTreeImage;
        int spiceTreeWidth;
        int spiceTreeHeight;
        if (usingBlankStreet)
        {
            spiceTreeImage = spiceTreePNGImage.readPNGImage();
            spiceTreeWidth = spiceTreePNGImage.readPNGImageWidth();
            spiceTreeHeight = spiceTreePNGImage.readPNGImageHeight();
        }
        else
        {
            spiceTreeImage = spiceTreeOutlinePNGImage.readPNGImage();
            spiceTreeWidth = spiceTreeOutlinePNGImage.readPNGImageWidth();
            spiceTreeHeight = spiceTreeOutlinePNGImage.readPNGImageHeight();
        }
        
        //calculate the pixel which marks the x,y of the tree - will be coloured differently
        int treeXYLoc = treeX + (treeY * geoWidth);
            
        // Now copy across the tree image, pixel by pixel - ignore transparent pixels
        for (int pixelYPosition = 0; pixelYPosition < spiceTreeHeight; pixelYPosition++) 
        {
            for (int pixelXPosition = 0; pixelXPosition < spiceTreeWidth; pixelXPosition++) 
            {  
                loc = pixelXPosition + (pixelYPosition * spiceTreeWidth);                
                aSpiceTree = alpha(spiceTreeImage.pixels[loc]);               
                if (aSpiceTree == 255)
                {
                    // Non-transparent pixel                   
                    streetLoc = (topX + pixelXPosition) + ((topY + pixelYPosition) * geoWidth);
                    if (streetLoc == treeXYLoc)
                    {
                        // Mark the spot with a green pixel
                        summaryStreetSnap.pixels[streetLoc] = #00FF0A;
                    }
                    else
                    {
                        summaryStreetSnap.pixels[streetLoc] = spiceTreeImage.pixels[loc];
                    }
                }
            }
        }
    }
    
    boolean platlineCrossesSpiceTreeImage(int x, int y)
    {
        // compare the spice tree image
        // For spice tree the matching fragment is at 126, 170 in the trant_spice_10_complete image, and has width 63, height 23, offset -34, -62
        
        // Need to convert the tree x,y to snap x,y
        int treeX = x + geoWidth/2;
        int treeY = y + geoHeight; 
        
        int topX = treeX - 34 - 126;
        int topY = treeY - 62 - 170;
        
        float aSpiceTree;
        int loc;
        int streetLoc;
        boolean platlineCrossed = false;
        
        // Point to the correct spice tree image depending on the street background
        PImage spiceTreeImage;
        int spiceTreeWidth;
        int spiceTreeHeight;
        if (usingBlankStreet)
        {
            spiceTreeImage = spiceTreePNGImage.readPNGImage();
            spiceTreeWidth = spiceTreePNGImage.readPNGImageWidth();
            spiceTreeHeight = spiceTreePNGImage.readPNGImageHeight();
        }
        else
        {
            spiceTreeImage = spiceTreeOutlinePNGImage.readPNGImage();
            spiceTreeWidth = spiceTreeOutlinePNGImage.readPNGImageWidth();
            spiceTreeHeight = spiceTreeOutlinePNGImage.readPNGImageHeight();
        }
        
        //calculate the pixel which marks the x,y of the tree - will be coloured differently
        int treeXYLoc = treeX + (treeY * geoWidth);
            
        // Now compare the tree image, pixel by pixel - ignore transparent pixels
        // Need to take account of fact that trees may be close together and so canopies may overlap. Therefore only check the portion of the image from 12 px above the x,y
        // Therefore start search at y = +220 = (62 - 12) + 170 
        for (int pixelYPosition = 220; pixelYPosition < spiceTreeHeight; pixelYPosition++) 
        {
            for (int pixelXPosition = 0; pixelXPosition < spiceTreeWidth; pixelXPosition++) 
            {  
                loc = pixelXPosition + (pixelYPosition * spiceTreeWidth);                
                aSpiceTree = alpha(spiceTreeImage.pixels[loc]);               
                if (aSpiceTree == 255)
                {
                    // Non-transparent pixel                   
                    streetLoc = (topX + pixelXPosition) + ((topY + pixelYPosition) * geoWidth);
                    if (streetLoc == treeXYLoc)
                    {
                        // check for a green pixel
                        if (summaryStreetSnap.pixels[streetLoc] != #00FF0A)
                        {
                            // Street pixel is not green as expected
                            platlineCrossed = true;
                        }
                    }
                    else
                    {
                        if (summaryStreetSnap.pixels[streetLoc] != spiceTreeImage.pixels[loc])
                        {
                            // Street pixel does not match the spice tree image - so been modified by plat line crossing it
                            platlineCrossed = true;
                        }
                    }
                }
            }
        }
        return platlineCrossed;
    }
    
    void createBlankStreetImage()
    {
        summaryStreetSnap = null;
        summaryStreetSnap = createImage(geoWidth, geoHeight, ARGB);
        summaryStreetSnap.loadPixels();
        for (int i = 0; i < summaryStreetSnap.pixels.length; i++) 
        {
            summaryStreetSnap.pixels[i] = STREET_BACKGROUND; 
        }
        
        usingBlankStreet = true;
    }
    
    void createStreetImage()
    {
        // Using the street name, load up the first street snap from the QA snap directory and use contents to populate the street image
        // Are only interested in street snaps with the correct h/w which matches the values read from the json geo file
        // If there are problems, then just create a blank street image instead. 

        String [] snapFilenames = Utils.loadFilenames(configInfo.readStreetSnapPath(), streetName, ".png");

        if (snapFilenames == null || snapFilenames.length == 0)
        {
            printToFile.printDebugLine(this, "Create blank street image - No valid street image files found in " + configInfo.readStreetSnapPath() + " for street " + streetName + " in directory " + configInfo.readStreetSnapPath(), 3);
            printToFile.printOutputLine("Create blank street image - No valid street image files found for " + streetName + "(" + streetTSID + ")" + " in directory " + configInfo.readStreetSnapPath() + "\n");
            createBlankStreetImage();
            return;
        }
        
        
        int i;
        StringList archiveSnapFilenames = new StringList();
 
        for (i = 0; i < snapFilenames.length; i++)
        {
            // Go through each name - only keep valid names for this street.
            // Stripping out files which start with the same name, but which are other streets
            // e.g. Tallish Crest/ Tallish Crest Subway Station. Otherwise the size check later 
            // will fail as these streets are different sizes.

            // First deal with specific cases of towers on streets
            // Aranna: Sabudana Drama - Sabudana Drama Towers - Sabudana Drama Towers Basement (unique) - Sabudana Drama Towers Floor 1-4 (unique)
            // Besara: Egret Taun - Egret Taun Towers - Egret Taun Towers Basement (unique) - Egret Taun Towers Floor 1-3 (unique)
            // Bortola: Hauki Seeks - Hauki Seeks Manor - Hauki Seeks Manor Basement (unique) - Hauki Seeks Manor Floor 1-3 (unique)
            // Groddle Meadow: Gregarious Towers - Gregarious Towers Basement (unique) - Gregarious Towers Floor 1-3 (unique)
            // Muufo: Hakusan Heaps - Hakusan Heaps Towers - Hakusan Heaps Towers Basement (unique) - Hakusan Heaps Towers Floor 1-2 (unique)
            if ((streetName.equals("Sabudana Drama")) || (streetName.equals("Egret Taun")) ||
                (streetName.equals("Hauki Seeks")) || (streetName.equals("Hakusan Heaps")))
            {
                // Need to strip out any of the Tower/Manor streets
                if ((snapFilenames[i].indexOf("Towers") == -1) && (snapFilenames[i].indexOf("Manor") == -1))
                {
                    // Is the actual street we want, so copy
                    archiveSnapFilenames.append(snapFilenames[i]);
                }
            }
            if ((streetName.equals("Sabudana Drama Towers")) || (streetName.equals("Egret Taun Towers")) ||
                (streetName.equals("Hauki Seeks Manor")) || (streetName.equals("Hakusan Heaps Towers")) ||
                (streetName.equals("Gregarious Towers")))
            {
                // Need to strip out the Basement/Floors streets
                if ((snapFilenames[i].indexOf("asement") == -1) && (snapFilenames[i].indexOf("loor") == -1))
                {
                    // Is the actual street we want, so copy
                    archiveSnapFilenames.append(snapFilenames[i]);
                } 
            }       
            else if (streetName.indexOf("Subway") == -1)
            { 
                // Street is not a subway - so remove any subway snaps
                if (snapFilenames[i].indexOf("Subway") == -1)
                {
                    // Snap is not the subway station, so keep
                    archiveSnapFilenames.append(snapFilenames[i]);
                }
                
            }
            else
            {
                // Valid subway street snap so keep
                archiveSnapFilenames.append(snapFilenames[i]);

            }
        }
        
        if (archiveSnapFilenames.size() == 0)
        {
            printToFile.printDebugLine(this, "Build blank street - No files found in rebuilt snap array = BUG for street " + streetName, 3);
            createBlankStreetImage();
            return;
        } 
        
        // Now copy across the first street snap into our street image file           
        for (i = 0; i < archiveSnapFilenames.size(); i++) 
        {
            // This currently never returns an error
            PNGFile streetSnap = new PNGFile(archiveSnapFilenames.get(i), true);
            
            // load up the image
            if (!streetSnap.setupPNGImage())
            {
                printToFile.printDebugLine(this, "Failed to load up image " + archiveSnapFilenames.get(i), 3);
            }
            else
            {
                // Loaded up street - now check if it is the right size
                if (streetSnap.readPNGImageWidth() != geoWidth || streetSnap.readPNGImageHeight() != geoHeight)
                {
                    printToFile.printDebugLine(this, "Skipping street snap " + streetSnap.readPNGImageName() + " because resolution is not " + 
                                                geoWidth + "x" + geoHeight + " pixels", 2);
                    streetSnap.unloadPNGImage();
                }
                else
                {
                    // street is good - so can be copied
                    //summaryStreetSnap = streetSnap.readPNGImage();
                    printToFile.printDebugLine(this, "Using street snap " + streetSnap.readPNGImageName() + " for street background ", 1);
                    summaryStreetSnap = createImage(geoWidth, geoHeight, ARGB);
                    summaryStreetSnap.loadPixels();
                    for (int j = 0; j < summaryStreetSnap.pixels.length; j++) 
                    {
                        summaryStreetSnap.pixels[j] = streetSnap.readPNGImage().pixels[j]; 
                    } 
                    summaryStreetSnap.loadPixels();
                    
                    // Unload this as no longer needed
                    streetSnap.unloadPNGImage();
                    return;
                }                
            }
        }  
        
        // Only reach here is not able to find snap of the right size - then need to create blank street
        printToFile.printDebugLine(this, "Create blank street for " + streetName + " as unable to find valid street snap of correct size to use as background ", 1);
        createBlankStreetImage();
        return;
    }
    
    boolean saveStreetImage()
    {
         summaryStreetSnap.updatePixels();
     
         // save in work/named directory
         String fname;
         
         fname = configInfo.readOutputStreetImagesPath() + File.separatorChar + streetName + "_summary.png";

         printToFile.printDebugLine(this, "Saving summary image to " + fname, 1);
         if (!summaryStreetSnap.save(fname))
         {
             printToFile.printDebugLine(this, "Unexpected error - failed to save street summary image to " + fname, 3);
             return false;
         }
         
         return true;
    }
 
    void drawBox(int x, int y)
    {
        // Draws a box around the tree which is at the x,y passed into this function
        int i;
        int j;
        int loc;
        int boxWidth = 348;
        int boxHeight = 272;
        int lineWidth = 3;
        int lineColour = BOX_COLOUR;
        
        // convert x,y to processing format after calculating the top LH corner relative to tree x,y
        int topX = (x - 170) + geoWidth/2;
        int topY = (y - 245) + geoHeight;
       
        printToFile.printDebugLine(this, "Passing in tree x,y " + x + "," + y + " which converts to top LH corner (processing) " + topX + "," + topY, 1);
        
        // Draw top/bottom horizontal lines
        for (i = 0; i < boxWidth + 1; i++)
        {
            for (j = 0; j < lineWidth; j++)
            {
                // Top pixel
                loc = topX + i + ((topY + j) * geoWidth);
                setPixel(summaryStreetSnap, loc, lineColour);
            
                // Bottom pixel
                //loc = topX + i + ((topY - j + bottomY - topY) * geoWidth);
                loc = (topX + boxWidth - i) + ((topY + boxHeight - j) * geoWidth);
                setPixel(summaryStreetSnap, loc, lineColour);
            }
        }
        
        // Draw vertical lines
        for (i = 0; i < boxHeight + 1; i++)
        {            
            for (j = 0; j < lineWidth; j++)
            {
                // Top pixel
                //loc = topX + j + ((topY + i + 1) * geoWidth);
                loc = topX + j + ((topY + i) * geoWidth);
                setPixel(summaryStreetSnap, loc, lineColour);
            
                // Bottom pixel
                //loc = bottomX - j + ((bottomY - i - 1) * geoWidth);
                loc = topX + boxWidth - j + ((topY + boxHeight - i) * geoWidth);
                setPixel(summaryStreetSnap, loc, lineColour);
            }
        }
    }
    
    void setPixel(PImage image, int loc, int colour)
    {
        // Only attempt to copy across the pixel if it in a valid place
        // Only need to use this function when generating boxes around items as usually
        // we know we are in range
        if ((loc > 0) && (loc < image.height * image.width))
        {
            // Is valid pixel
            image.pixels[loc] = colour;
        }
    }

    boolean getJSONFile(String TSID)
    {
        String JSONFileName = TSID + ".json";
        String sourcePath; 
        String destPath = workingDir + File.separatorChar + "OrigJSONs" + File.separatorChar + JSONFileName;
        
        if (configInfo.readUseVagrantFlag())
        {
           sourcePath = configInfo.readPersdataPath() + File.separatorChar + JSONFileName;
            // First check file exists in persdata
            File file = new File(sourcePath);
            if (!file.exists())
            {
                // Retrieve from fixtures
                if (TSID.startsWith("L") || TSID.startsWith("G"))
                {
                    sourcePath = configInfo.readFixturesPath() + File.separatorChar + "locations-json" + File.separatorChar + JSONFileName;
                }
                else
                {
                    sourcePath = configInfo.readFixturesPath() + File.separatorChar + "world-items" + File.separatorChar + JSONFileName;
                }
                file = new File(sourcePath);
                if (!file.exists())
                {
                    // Can't get file so give up - error will be reported when do actual processing
                    printToFile.printDebugLine(this, "Unable to find file on vagrant - " + sourcePath, 3);
                    return false;
                }

            }                          
            // copy file to OrigJSONs directory
            if (!copyFile(sourcePath, destPath))
            {
                printToFile.printDebugLine(this, "Unable to copy JSON file - " + sourcePath + " to " + destPath, 3);
                return false;
            }
            printToFile.printDebugLine(this, "Copied JSON file - " + sourcePath + " to " + destPath, 1);
        }
        else
        {
            // Use sftp to download the file from server
            sourcePath = configInfo.readPersdataPath() + "/" + JSONFileName;
            // See if file exists in persdata     
            if (!QAsftp.executeCommand("get", sourcePath, destPath))
            {
                // See if file exists in fixtures
                if (TSID.startsWith("L") || TSID.startsWith("G"))
                {
                    sourcePath = configInfo.readFixturesPath() + "/locations-json/" + JSONFileName;
                }
                else
                {
                    sourcePath = configInfo.readFixturesPath() + "/world-items/" + JSONFileName;
                }
                
                if (!QAsftp.executeCommand("get", sourcePath, destPath))
                {
                    // Can't get JSON file from fixtures either - so give up - error will be reported when do actual processing
                    printToFile.printDebugLine(this, "Unable to find JSON file on server - " + sourcePath, 3);
                    return false;
                }
            } 
            
            printToFile.printDebugLine(this, "Downloaded JSON file - " + sourcePath + " to " + destPath, 1);
        }
        return true;
    }
    
    // Simple functions to read/set variables   
    public boolean readOkFlag()
    {
        return okFlag;
    } 
    
    public String readStreetName()
    {
        return streetName;
    }
    
    public String readHubID()
    {
        return hubID;
    }
    
    public String readStreetTSID()
    {
        return streetTSID;
    }
                  
    public boolean readInvalidStreet()
    {
        return invalidStreet;
    }
    
    public boolean readSkipStreet()
    {
        return skipStreet;
    }
   
    public int readGeoHeight()
    {
        return geoHeight;
    }
    
    public int readGeoWidth()
    {
        return geoWidth;
    }
    
    
    public boolean readStreetInitialisationFinished()
    {
        return streetInitialisationFinished;
    }
    
    public String readCurrentItemTSIDBeingProcessed()
    {
        if (itemBeingProcessed >= streetItems.size())
        {
            return "";
        }
        else
        {
            JSONObject thisItem = Utils.readJSONObjectFromJSONArray(streetItems, itemBeingProcessed, true); 
            if (!Utils.readOkFlag())
            {
                printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
                return "";
            }

            String itemTSID = Utils.readJSONString(thisItem, "tsid", true);
            if (!Utils.readOkFlag())
            {
                // Failed
                printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
                printToFile.printDebugLine(this, "Failed to read Item TSID string from array in street JSON  ", 3);
                return "";
            }
            else
            {
                return (itemTSID);
            }
        }
    }
    
    class Platline
    {
        // JSON key
        String platlineKey;
        
        // Eleven co-ordinates
        int startX;
        int startY;
        int endX;
        int endY;
        // processing format co-ords
        int procStartX;
        int procStartY;
        int procEndX;
        int procEndY;
        
        boolean crossesTreeRoot;
        
        Platline(String platKey, int x1, int y1, int x2, int y2)
        {
            // Want to save this so that the line always goes from left to right
            if (x1 > x2)
            {
                startX = x2;
                startY = y2;
                endX = x1;
                endY = y1;
            }
            else
            {
                startX = x1;
                startY = y1;
                endX = x2;
                endY = y2;
            }
            
            // Convert into Proccessing pixel array x,y values (i.e. 0,0 is top LH corner)
            procStartX = startX + geoWidth/2;
            procStartY = startY + geoHeight;
            procEndX = endX + geoWidth/2;
            procEndY = endY + geoHeight;
            
            platlineKey = platKey;
            
            crossesTreeRoot = false;
            
        }
          
        void drawAliasedLine(PImage streetImage, int lineColour)
        {
            // Draws a line between the start/end points - if it crosses the spice tree then returns true
            
            // Works out the y value ... and then does rough aliasing on pixels above
            // Line is always 2 pixels which are full colour, and then partial colour on pixel above and below
            // e.g. y = 12.3                 y = 12.8
            //      y = 11 (70%)             y = 11 (20%)
            //      y = 12 (100%)            y = 12 (100%)
            //      y = 13 (100%)            y = 13 (100%)
            //      y = 14 (30%)             y = 14 (80%)
            int i;
            float m;
        
            printToFile.printDebugLine(this, "Drawing line " + platlineKey + " from x,y " + startX + "," + startY + " to x,y " + endX + "," + endY + " with colour " + lineColour, 1);
            printToFile.printDebugLine(this, "Also = line from x,y " + procStartX + "," + procStartY + " to x,y " + procEndX + "," + procEndY + " with colour " + lineColour, 1);
        
            // Slope of line between 2 points
            m = float(procEndY - procStartY)/float(procEndX - procStartX);
            printToFile.printDebugLine(this, " m = " + m, 1);
            // y = m(x - x1) + y1
            // Working from x1 to x2, recalculate y at that point and mark pixel at that location
            for (i = 0; i < procEndX - procStartX + 1; i++)
            {
                int x = procStartX + i;
                float y = (m * (x - procStartX)) + procStartY;
                
                float fractionY = y % 1;
                int intY = int(y);
                                
                // Now colour the 4 pixels
                // Top pixel
                if (colourPixel(streetImage, x, intY - 1, color (lineColour, int(map(1-fractionY, 0, 1, 0, 255)))))
                {
                    crossesTreeRoot = true;
                }
                              
                // 2nd pixel
                if (colourPixel(streetImage, x, intY, lineColour))
                {
                    crossesTreeRoot = true;
                }
                
                // 3rd pixel
                if (colourPixel(streetImage, x, intY + 1, lineColour))
                {
                    crossesTreeRoot = true;
                }  
                
                // Bottom pixel
                if (colourPixel(streetImage, x, intY + 2, color (lineColour, int(map(fractionY, 0, 1, 0, 255)))))
                {
                    crossesTreeRoot = true;
                }
            }
            
            // Mark start/end pixel with black line
            drawVerticalLine(streetImage, procStartX, procStartY, 8, #000000);
            drawVerticalLine(streetImage, procEndX, procEndY, 8, #000000);
            
            return;
        }
        
        boolean colourPixel(PImage streetImage, int x, int y, color c)
        {
            boolean crossesRoot = false;
            color backgroundPixel;
            int loc = x + (y * geoWidth); 
            
            if ((loc > 0) && (loc < geoHeight * geoWidth))
            {
                backgroundPixel = streetImage.pixels[loc];
                if (usingBlankStreet)
                {
                    if (backgroundPixel != color(STREET_BACKGROUND))
                    {
                        // Plat line is cross the tree so set flag
                    }
                    //Take account of background street colour - otherwise get whitish colour on a grey street
                    streetImage.pixels[loc] = lerpColor(c, backgroundPixel, 0.5);
                }
                else
                {
                    if (backgroundPixel == color(SPICE_TREE) || backgroundPixel == color(SPICE_TREE_ROOTS))
                    {
                        // Plat line is cross the tree so set flag
                        crossesRoot = true;
                        // Merge red line with purple (???)
                        streetImage.pixels[loc] = lerpColor(c, backgroundPixel, 0.5);
                    }
                    else
                    {
                        // Just draw red line across scenery
                        streetImage.pixels[loc] = c;
                    }
                }
            }
            else
            {
                printToFile.printDebugLine(this, "ERROR Attempting to write to pixel at " + x + "," + y, 3);
            }
            
            return crossesRoot;
        }
        
        void drawVerticalLine(PImage streetImage, int x, int y, int lineHeight, int lineColour)
        {
            int loc;
            int i;
            
            for (i = 0 - lineHeight/2; i < lineHeight/2; i++)
            {
                loc = x + ((y + i) * geoWidth);
                if ((loc > 0) && (loc < geoHeight * geoWidth))
                {
                    streetImage.pixels[loc] = lineColour;
                }
            }
        }
             
        public int readStartX()
        {
            return startX;
        }
        public int readStartY()
        {
            return startY;
        }
        public int readEndX()
        {
            return endX;
        }
        public int readEndY()
        {
            return endY;
        }
        
        public boolean readcrossesTreeRoot()
        {
            return crossesTreeRoot;
        }
    }
    
}