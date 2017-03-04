class SummaryChanges implements Comparable
{
    // small class which should make it easier to output/summarise in the output
    
    // Used to populate the results field
    final static int SKIPPED = 1;
    final static int TREE_OK = 2;
    final static int TREE_BAD = 3;
    
    // Populate fields I might want to sort on
    int itemX;
    int itemY;
    int result; 
    String itemTSID;
    String itemClassTSID;
    boolean platlineProblem;
          
    public SummaryChanges( ItemInfo item, boolean platline)
    {
        itemX = item.readItemX();
        itemY = item.readItemY();
        itemTSID = item.readItemTSID();
        itemClassTSID = item.readItemClassTSID();
        platlineProblem = platline;
        
        String s;
        s = itemTSID + " (" + itemClassTSID + ") x,y=" + itemX + "," + itemY;
        
        if (item.readSkipThisItem())
        {
            s = s + " (SKIPPED)";
            result = SKIPPED;
        }
        else if (platlineProblem)
        {
           result = TREE_BAD; 
           s = s + " (TREE - BAD)";
        }
        else
        {
           result = TREE_OK; 
           s = s + " (TREE - OK)";
        }
        
        printToFile.printDebugLine(this, s, 1);
        return;
         
    }

    public int compareTo(Object o) 
    {
        SummaryChanges n = (SummaryChanges) o;
        int X1 = itemX;
        int X2 = n.itemX;
        
        if (X1 > X2)
        {
            return 1;
        }
        else
        {
            return -1;
        }
    }
    
    public int readItemX()
    {
        return itemX;
    }
    
    public int readItemY()
    {
        return itemY;
    }
    
    public int readResult()
    {
        return result;
    }
       
    public String readItemTSID()
    {
        return itemTSID;
    }
    
    public String readItemClassTSID()
    {
        return itemClassTSID;
    }

}