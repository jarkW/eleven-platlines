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
    
    final static int STREET_BACKGROUND = #BFBFBF;
    final static int PLATLINE_COLOUR =  #FF002B;
    final static int PLATLINE_PURPLE = #9717E8;
    
     
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
        // Now need to chain down through this object, extracting the x,y pairs from each 
        // As we don't know the string for each platline name, need to do it this clunky way                   
        List<String> platlineList = new ArrayList(platformLinesObject.keys());
        printToFile.printDebugLine(this, "Reading geo file - number of plat lines is " + platlineList.size(), 2);
                    
        for (i = 0; i < platlineList.size(); i++)
        {
            JSONObject platLineObj = Utils.readJSONObject(platformLinesObject, platlineList.get(i), true);
            if (Utils.readOkFlag() && platLineObj != null)
            {
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
                                        platlines.add(new Platline(x1, y1, x2, y2));
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
        
        // Create blank street image
        createBlankStreetImage();
        
/*        
                        // Save an image of the street  - with items marked with different coloured squares to show if found/missing
                // Allows the user to quickly see what was found/missing against a street snap
                if (!saveStreetFoundSummaryAsPNG(itemResults))
                {
                    failNow = true;
                    return false;
                }
  */    
  
        // Draw on the plat lines
        for (i = 0; i < platlines.size(); i++)
        {
            //platlines.get(i).drawLine(summaryStreetSnap, PLATLINE_COLOUR);
            platlines.get(i).drawAliasedLine(summaryStreetSnap, PLATLINE_COLOUR);
        } 
        // Update pixels
        summaryStreetSnap.updatePixels();
        
        // Cycle through all items - if it is a tree then put spice tree at appropriate x,y
        // could use sortResultsByXY(itemResults); - if each result contains the x,y tsid etc and only had trees in this array?
        for (i = 0; i < itemInfo.size(); i++) 
        {
            boolean treeCrossesPlatline = false;
            if (!itemInfo.get(i).readSkipThisItem())
            {
                // Item is patch/tree - so put image of spice tree at this x,y
                treeCrossesPlatline = addSpiceTreeImage(itemInfo.get(i).readItemX(), itemInfo.get(i).readItemY());
            }
            // Store the result - will include details of whether tree crosses the plat line or not
            itemResults.add(new SummaryChanges(itemInfo.get(i), treeCrossesPlatline));
        }
        
        // Update pixels
        summaryStreetSnap.updatePixels();
        
        // Save file
        if (!saveStreetImage())
        {
            failNow = true;
            return false;
        }
        
        
        // Check to see if plat lines intersect tree anywhere - and draw box around tree, log to output file
        
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
    
    boolean addSpiceTreeImage(int x, int y)
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
        boolean platlineCrossed = false;
        PImage spiceTreeImage = spiceTreePNGImage.readPNGImage();
        int spiceTreeWidth = spiceTreePNGImage.readPNGImageWidth();
        int spiceTreeHeight = spiceTreePNGImage.readPNGImageHeight();
        
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
                        if (summaryStreetSnap.pixels[streetLoc] != STREET_BACKGROUND)
                        {
                            // Set flag, and colour plat line purple so can clearly see where interface
                            platlineCrossed = true;
                            summaryStreetSnap.pixels[streetLoc] = PLATLINE_PURPLE;
                        }
                        else
                        {
                            summaryStreetSnap.pixels[streetLoc] = spiceTreeImage.pixels[loc];
                        }
                    }
                }
            }
        }
        return platlineCrossed;
    }
    
    boolean itemIsTree(int n)
    {
        //println("itemBeingProcessed is ", n);
        if (itemInfo.get(n).readSkipThisItem())
        {
            // Item is not tree
            return false;
        }
        return true;
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

    /*
    boolean saveStreetSummaryAsPNG(ArrayList<SummaryChanges> itemResults)
    {
        // Loops through the item results and draws in the matching fragments on a street PNG
        // Skipped items are ignored
        int i;
        int j;
        int locItem;
        int locStreet;
        int topX;
        int topY;
        int bottomX;
        int bottomY;
        
        
            
        for (int n = 0; n < itemResults.size(); n++)
        {   
            if (itemResults.get(n).readResult() > SummaryChanges.SKIPPED)
            {
                // Only draw a square for items which are found to overlap the platline
                
                                
                PImage bestFragment = bestItemMatchInfo.readColourItemFragment();
                
                if (bestFragment == null)
                {
                    printToFile.printDebugLine(this, "Unexpected error - failed to load best match colour/tinted item fragment " + bestItemMatchInfo.readBestMatchItemImageName(), 3);
                    return false;
                }
                
                // Need to account for the offset of the item image from item x,y in JSON
                // The results array list contains the final x,y - whether original x,y (missing) or the new x,y (found)
                topX = itemResults.get(n).readItemX() + geoWidth/2 + bestItemMatchInfo.readItemImageXOffset();
                topY = itemResults.get(n).readItemY() + geoHeight + bestItemMatchInfo.readItemImageYOffset();                 

                // Now copy the pixels of the fragment into the correct place - so can see mismatches easily
                float a;
                int boxColour;
                int boxHeight;
                int boxWidth;
                int lineWidth;
                                               
                // If this is a missing item - then draw a red box around the item to show unsure - print %match also?
                // For all other items draw a black box to show found
                if (itemResults.get(n).readResult() == SummaryChanges.MISSING || itemResults.get(n).readResult() == SummaryChanges.MISSING_DUPLICATE)
                {
                    // Centre it on the original startX/StartY and have the size of the search radius
                    boxColour = ITEM_MISSING_COLOUR;
                    
                    // Put a 9 pixel dot at the centre of the box
                    locStreet = (topX-1) + ((topY-1) * geoWidth);
                    summaryStreetSnap.pixels[locStreet] = boxColour;
                    summaryStreetSnap.pixels[locStreet+1] = boxColour;
                    summaryStreetSnap.pixels[locStreet+2] = boxColour;
                    locStreet = (topX-1) + ((topY) * geoWidth);
                    summaryStreetSnap.pixels[locStreet] = boxColour;
                    summaryStreetSnap.pixels[locStreet+1] = boxColour;
                    summaryStreetSnap.pixels[locStreet+2] = boxColour;
                    locStreet = (topX-1) + ((topY+1) * geoWidth);
                    summaryStreetSnap.pixels[locStreet] = boxColour;
                    summaryStreetSnap.pixels[locStreet+1] = boxColour;
                    summaryStreetSnap.pixels[locStreet+2] = boxColour;
                    
                    boxHeight = configInfo.readSearchRadius() * 2;
                    boxWidth = configInfo.readSearchRadius() * 2;
                    topX = topX - configInfo.readSearchRadius();
                    topY = topY - configInfo.readSearchRadius();      
                    lineWidth = 3;
                }
                else
                {
                    boxColour = ITEM_FOUND_COLOUR;
                    boxHeight = bestFragment.height;
                    boxWidth = bestFragment.width;
                    lineWidth = 1;
                }
                bottomX = topX + boxWidth;
                bottomY = topY + boxHeight;
                
                printToFile.printDebugLine(this, "Top x,y " + topX + "," + topY + " Bottom x,y " + bottomX + "," + bottomY + " boxHeight " + boxHeight + " boxWidth " + boxWidth + " lineWidth " + lineWidth, 1);
                // Draw out the box
                drawBox(summaryStreetSnap, topX-lineWidth, topY-lineWidth, bottomX+lineWidth, bottomY+lineWidth, lineWidth, boxColour);
                
                // Now fill in the fragment - for found items - it is inside the red box. But for missing items need to be to the side of the red box
                int x;
                int y;
                if (itemResults.get(n).readResult() == SummaryChanges.MISSING || itemResults.get(n).readResult() == SummaryChanges.MISSING_DUPLICATE)
                {
                    x = itemResults.get(n).readItemX() + geoWidth/2 + bestItemMatchInfo.readItemImageXOffset() - bestFragment.width/2;
                    // Need to work out the best place for the red box
                    if (bestFragment.height > (topY + 2*lineWidth))
                    {
                        // Will go past top of image, so add to mid bottom of red box
                        
                        y = bottomY + lineWidth; 
                        
                    }
                    else
                    {
                        y = topY - bestFragment.height - lineWidth;
                    }
                    // Draw red box for this sample
                    boxHeight = bestFragment.height;
                    boxWidth = bestFragment.width;
                    lineWidth = 1;
                    drawBox(summaryStreetSnap, x-lineWidth, y-lineWidth, x + boxWidth +lineWidth, y + boxHeight+lineWidth, lineWidth, boxColour);
                }
                else
                {
                    // In the found case, it matches the top corner of the box. No need to draw additional box
                    x = topX;
                    y = topY;
                }
                
                for (i = 0; i < bestFragment.height; i++) 
                {
                    for (j = 0; j < bestFragment.width; j++)
                    {
                        locItem = j + (i * bestFragment.width);
                        locStreet = (x + j) + ((y + i) * geoWidth);
                        
                        a = alpha(bestFragment.pixels[locItem]);
                
                        // Copy across the pixel to the street summary if it is not transparent
                        if (a == 255)
                        {
                            // Copy across the pixel to the street summary image
                            setPixel(summaryStreetSnap, locStreet, bestFragment.pixels[locItem]);
                        }
                    }        
                }
            }
        } 
        
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
         
         // Clean up this variable as no longer needed
         summaryStreetSnap = null;
         System.gc();

         return true;   
        
    }
 */ 
    
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
        int startX;
        int startY;
        int endX;
        int endY;
        Platline(int x1, int y1, int x2, int y2)
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
        }
 /*
        void drawAliasedLine(PImage streetImage, int lineColour)
        {
            // Draws a line between the start/end points
            int i;
            int loc;
            float m;
        
            // Convert into Proccessing pixel array x,y values (i.e. 0,0 is top LH corner)
            float x1 = startX + geoWidth/2;
            float y1 = startY + geoHeight;
            float x2 = endX + geoWidth/2;
            float y2 = endY + geoHeight;
        
            printToFile.printDebugLine(this, "Drawing line from x,y " + startX + "," + startY + " to x,y " + endX + "," + endY, 1);
            printToFile.printDebugLine(this, "Also = line from x,y " + x1 + "," + y1 + " to x,y " + x2 + "," + y2, 1);
        
            // Slope of line between 2 points
            m = (y2 - y1)/(x2 - x1);
            printToFile.printDebugLine(this, " m = " + m, 1);
            // y = m(x - x1) + y1
            // Working from x1 to x2, recalculate y at that point and mark pixel at that location
            for (i = 0; i < x2 - x1 + 1; i++)
            {
                float x = x1 + i;
                float y = (m * (x - x1)) + y1;
                
                // Now try to do anti-aliased line
                // Have the main pixel at y, but the depth of colour depends on how close it is to integer value. 
                // Rest of fraction is given to pixel above or below depending.
                
                // alpha=255 = solid colour, alpha = 0 = transparent
                                aSpiceTree = alpha(spiceTreeImage.pixels[loc]);               
                
                
                loc = int(x + (y * geoWidth));
                // Only copy across the pixel if inside the image - otherwise report an error                
                if ((loc > 0) && (loc < geoHeight * geoWidth))
                {
                    streetImage.pixels[loc] = lineColour;
                }
                else
                {
                    printToFile.printDebugLine(this, "ERROR Attempting to write to pixel at " + x + "," + y, 3);
                }
                // Add second pixel below
                loc = x + int((y + 1) * geoWidth);
                // Only copy across the pixel if inside the image - otherwise report an error 
                if ((loc > 0) && (loc < geoHeight * geoWidth))
                {
                    streetImage.pixels[loc] = lineColour;
                }
                else
                {
                    printToFile.printDebugLine(this, "ERROR Attempting to write to pixel at " + x + "," + y, 3);
                }       
            }
        }
*/        
        void drawLine(PImage streetImage, int lineColour)
        {
            // Draws a line between the start/end points
            int i;
            int loc;
            float m;
        
            // Convert into Proccessing pixel array x,y values (i.e. 0,0 is top LH corner)
            int x1 = startX + geoWidth/2;
            int y1 = startY + geoHeight;
            int x2 = endX + geoWidth/2;
            int y2 = endY + geoHeight;
        
            printToFile.printDebugLine(this, "Drawing line from x,y " + startX + "," + startY + " to x,y " + endX + "," + endY, 1);
            printToFile.printDebugLine(this, "Also = line from x,y " + x1 + "," + y1 + " to x,y " + x2 + "," + y2, 1);
        
            // Slope of line between 2 points
            m = float(y2 - y1)/float(x2 - x1);
            printToFile.printDebugLine(this, " m = " + m, 1);
            // y = m(x - x1) + y1
            // Working from x1 to x2, recalculate y at that point and mark pixel at that location
            for (i = 0; i < x2 - x1 + 1; i++)
            {
                int x = x1 + i;
                int y = int(m * (x - x1)) + y1;
                loc = x + int(y * geoWidth);
                // Only copy across the pixel if inside the image - otherwise report an error                
                if ((loc > 0) && (loc < geoHeight * geoWidth))
                {
                    streetImage.pixels[loc] = lineColour;
                }
                else
                {
                    printToFile.printDebugLine(this, "ERROR Attempting to write to pixel at " + x + "," + y, 3);
                }
                // Add second pixel below
                loc = x + int((y + 1) * geoWidth);
                // Only copy across the pixel if inside the image - otherwise report an error 
                if ((loc > 0) && (loc < geoHeight * geoWidth))
                {
                    streetImage.pixels[loc] = lineColour;
                }
                else
                {
                    printToFile.printDebugLine(this, "ERROR Attempting to write to pixel at " + x + "," + y, 3);
                }       
            }

        }
        //https://en.wikipedia.org/wiki/Xiaolin_Wu's_line_algorithm
        void plot(PImage img, int x, int y, int lineColour, float brightness)
        {
            //plot the pixel at (x, y) with brightness c (where 0 ≤ c ≤ 1)
            int loc = x + (y * geoWidth);
            float a = map(brightness, 0, 1, 0, 255);
            color c = color(lineColour, a);
            // Only copy across the pixel if inside the image - otherwise report an error                
            if ((loc > 0) && (loc < geoHeight * geoWidth))
            {
                img.pixels[loc] = c;
            }
            else
            {
                printToFile.printDebugLine(this, "ERROR Attempting to write to pixel at " + x + "," + y, 3);
            }            
        }

        // integer part of x
        int ipart(float x)
        {
            return int(x);
        }

        // version of round function?
        int roundFloat(float x)
        {
            return ipart(x + 0.5);
        }
        
        // fractional part of x
        float fpart(float x)
        {
            if (x < 0)
            {
                return (1 - (x - floor(x)));
            }
            else
            {
                return (x - floor(x));
            }
        }

        float rfpart(float x)
        {
            return (1 - fpart(x));
        }

        void drawAliasedLine(PImage StreetImage, int lineColour)
        {
            int x0 = startX;
            int y0 = startY;
            int x1 = endX;
            int y1 = endY;
            
            boolean steep = abs(y1 - y0) > abs(x1 - x0);
    
            if (steep)
            {             
                //swap(x0, y0)
                x0 = startY;
                y0 = startX;
                //swap(x1, y1)
                x1 = endY;
                y1 = endX;
            }

            if (x0 > x1)
            {
                //swap(x0, x1)
                x0 = endX;
                x1 = startX;
                //swap(y0, y1)
                y0 = endY;
                y1 = startY;
            }
    
            float dx = x1 - x0;
            float dy = y1 - y0;
            float gradient = dy / dx;
            if (dx == 0.0)
            {
                gradient = 1.0;
            }

            // handle first endpoint
            int xend = roundFloat(x0);
            float yend = y0 + gradient * (xend - x0);
            float xgap = rfpart(x0 + 0.5);
            int xpxl1 = xend; // this will be used in the main loop
            int ypxl1 = ipart(yend);
    
            if (steep)
            {
                plot(StreetImage, ypxl1,   xpxl1, lineColour, rfpart(yend) * xgap);
                plot(StreetImage, ypxl1+1, xpxl1, lineColour,  fpart(yend) * xgap);
            }
            else
            {
                plot(StreetImage, xpxl1, ypxl1  , lineColour, rfpart(yend) * xgap);
                plot(StreetImage, xpxl1, ypxl1+1, lineColour,  fpart(yend) * xgap);
            }

            float intery = yend + gradient; // first y-intersection for the main loop
    
            // handle second endpoint
            xend = roundFloat(x1);
            yend = y1 + (gradient * (xend - x1));
            xgap = fpart(x1 + 0.5);
            int xpxl2 = xend; //this will be used in the main loop
            int ypxl2 = ipart(yend);
            if (steep)
            {
                plot(StreetImage, ypxl2  , xpxl2,lineColour,  rfpart(yend) * xgap);
                plot(StreetImage, ypxl2+1, xpxl2,lineColour,   fpart(yend) * xgap);
            }
            else
            {
                plot(StreetImage, xpxl2, ypxl2, lineColour,  rfpart(yend) * xgap);
                plot(StreetImage, xpxl2, ypxl2+1,lineColour,  fpart(yend) * xgap);
            }
    
            // main loop
            int x;
            if (steep)
            {
                for (x = xpxl1 + 1; x < xpxl2; x++)
                {
                    plot(StreetImage, ipart(intery)  , x,lineColour,  rfpart(intery));
                    plot(StreetImage, ipart(intery)+1, x,lineColour,   fpart(intery));
                    intery = intery + gradient;
                }
            }
            else
            {
                for (x = xpxl1 + 1; x < xpxl2; x++)
                {
                    plot(StreetImage, x, ipart(intery), lineColour,  rfpart(intery));
                    plot(StreetImage, x, ipart(intery)+1,lineColour,  fpart(intery));
                    intery = intery + gradient;
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
    }
    
}