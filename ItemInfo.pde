class ItemInfo
{
    boolean okFlag;
   
    boolean skipThisItem; // Item we are not scanning for
    
    // Read in from I* file
    JSONObject itemJSON;
    String itemTSID;
    String itemClassTSID;
    int    itemX;
    int    itemY;
                  
    // constructor/initialise fields
    public ItemInfo(JSONObject item)
    {
        okFlag = true;
        itemJSON = null;
        itemX = 0;
        itemY = 0;
                
        skipThisItem = false;

        itemTSID = Utils.readJSONString(item, "tsid", true);
        if (!Utils.readOkFlag() || itemTSID.length() == 0)
        {
            printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
            okFlag = false;
        }
        else
        {
            // Read in the label to supply additional info - but as sometimes is set to null, be able to handle this without failing
            String itemLabel = Utils.readJSONString(item, "label", false);
            printToFile.printDebugLine(this, "ItemInfo constructor item tsid is " + itemTSID + "(" + itemLabel + ")", 1);
        }
    }
      
    public boolean initialiseItemInfo()
    {                
        // Now open the relevant I* file - use the version which has been downloaded/copied to OrigJSONs
        // If it is not there then report an error
        String itemFileName = workingDir + File.separatorChar + "OrigJSONs" + File.separatorChar+ itemTSID  + ".json";
        File file = new File(itemFileName);
        if (!file.exists())
        {
            printToFile.printDebugLine(this, "Missing file - " + itemFileName, 3);
            return false;
        } 
                
        printToFile.printDebugLine(this, "Item file name is " + itemFileName, 1); 

        // Now read the item JSON file
        itemJSON = null;
        try
        {
            itemJSON = loadJSONObject(itemFileName);
        }
        catch(Exception e)
        {
            println(e);
            printToFile.printDebugLine(this, "Failed to load the item json file " + itemFileName, 3);
            return false;
        }
        
        printToFile.printDebugLine(this, "Loaded item JSON OK", 1);
                
        // These fields are always present - so if missing = error
        itemX = Utils.readJSONInt(itemJSON, "x", true);
        if (!Utils.readOkFlag())
        {
            printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
            return false;
        }
        itemY = Utils.readJSONInt(itemJSON, "y", true);
        if (!Utils.readOkFlag())
        {
            printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
            return false;
        }
        itemClassTSID = Utils.readJSONString(itemJSON, "class_tsid", true);
        if (!Utils.readOkFlag() || itemClassTSID.length() == 0)
        {
            printToFile.printDebugLine(this, Utils.readErrMsg(), 3);
            return false;
        }
               
        // Before proceeding any further need to check if this is a tree/patch
        //  - skip if not
        if (!validItemToCheckFor())
        {
            // NB - safer to keep it in the item array, and check this flag
            // before doing any actual checking/writing
            printToFile.printDebugLine(this, "Skipping item (" + itemTSID + ") class_tsid " + itemClassTSID, 1);
            skipThisItem = true;
            return true;
        }

        printToFile.printDebugLine(this, itemTSID + " class_tsid " + itemClassTSID + " with x,y " + str(itemX) + "," + str(itemY), 2); 
 
        return true;
    } 
    
    boolean validItemToCheckFor()
    {       
        // Returns true if this a tree or patch  
        // Don't need to include enchanted trees in this list as they are not player planted trees
        if ((itemClassTSID.indexOf("trant", 0) == 0) || (itemClassTSID.equals("wood_tree")) || (itemClassTSID.indexOf("patch", 0) == 0))
        {
            return true;
        }
        else
        {
            return false;
        }
    }
    
    // Simple functions to read/set variables   
    public int readItemX()
    {
        return itemX;
    }
    public int readItemY()
    {
        return itemY;
    }
    public String readItemClassTSID()
    {
        return itemClassTSID;
    }
    public String readItemTSID()
    {
        return itemTSID;
    }
      
    public boolean readSkipThisItem()
    {
        return skipThisItem;
    }
    
    public boolean readOkFlag()
    {
        return okFlag;
    } 

}