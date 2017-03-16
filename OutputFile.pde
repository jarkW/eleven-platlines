class OutputFile
{
    PrintWriter output;
    boolean initFlag;
    String fname;
    boolean isDebugFile;
    int totalGoodTreeCount;
    int totalBadTreeCount;
        
    public OutputFile(String filename, boolean debugFileFlag)
    {
        output = null;
        initFlag = false;
        fname = filename;
        isDebugFile = debugFileFlag;
        totalGoodTreeCount = 0;
        totalBadTreeCount = 0;
    }
        
    public boolean openOutputFile()
    {
        // open the file ready for writing     
        try
        {
            output = createWriter(fname);
        }
        catch(Exception e)
        {
            println(e);
            if (isDebugFile)
            {
                // Cannot write this error to debug file ...
                println("Failed to open debug file");
            }
            else
            {
                printToFile.printDebugLine(this, "Failed to open file " + fname, 3);
            }
            displayMgr.showErrMsg("Failed to open file " + fname, true);
            return false;
        }
        
        initFlag = true;
        return true;
    }
        
    public void writeHeaderInfo()
    {
        printLine("Details of trees and platlines");
    }
    
    public void printLine(String info)
    {
    
        // Do nothing if not yet initialised this object
        if (!initFlag)
        {
            return;
        }
    
        // Output line 
        output.println(info);
        output.flush();
    }
    
    public void writeStreetHeaderInfo()
    {
        String s = "============================================================================================";
        printLine(s);
        s = "\nResults for " + streetInfo.readStreetName() + " (" + streetInfo.readStreetTSID() + ")";
        printLine(s);
           
        // print out information about street size
        s = "Street is " + streetInfo.readGeoWidth() + "x" + streetInfo.readGeoHeight() + " pixels";
        printLine(s);
        return;
    }
 
    public boolean printSummaryData(ArrayList<SummaryChanges> itemResults)
    {
        String s;
        // Now print out the summary array - what is printed depends on the flag
  
        // Sort array by x co-ord so listing items from L to R
        // There won't be any colocated items because these have already been resolved
        Collections.sort(itemResults);
   
        int treeGoodCount = 0;
        int treeBadCount = 0;
        int skippedCount = 0;
            
        for (int i = 0; i < itemResults.size(); i++)
        {
            s = "";    
        
            switch (itemResults.get(i).readResult())
            {
                case SummaryChanges.SKIPPED:
                    s = s + "SKIPPED " + itemResults.get(i).readItemTSID() + ": " + itemResults.get(i).readItemClassTSID();
                    skippedCount++;
                    break;  
                     
               case SummaryChanges.TREE_OK:
                    s = s + "GOOD TREE " + itemResults.get(i).readItemTSID() + ": " + itemResults.get(i).readItemClassTSID();
                    treeGoodCount++;
                    break;   
                    
               case SummaryChanges.TREE_BAD:
                    s = s + "BAD TREE " + itemResults.get(i).readItemTSID() + ": " + itemResults.get(i).readItemClassTSID();
                    treeBadCount++;
                    break;   
                        
                default:
                    printToFile.printDebugLine(this, "Unexpected results type " + itemResults.get(i).readResult(), 3);
                    displayMgr.showErrMsg("Unexpected results type " + itemResults.get(i).readResult(), true);
                    failNow = true;
                    return false;  
            }
            
            // In in the co-ordinate information
            if (itemResults.get(i).readResult() > SummaryChanges.SKIPPED)
            {
                s = s + " at x,y " + itemResults.get(i).readItemX() + "," + itemResults.get(i).readItemY();
                printLine(s);
            }
        }
    
        // Dump out the count summary of items missing/skipped/changed                
        s = "\nSkipped " + skippedCount + " items, ";
        if (treeGoodCount == 1)
        {
            s = s + + treeGoodCount + " good tree, ";
        } 
        else
        {
            s = s + + treeGoodCount + " good trees, ";
        }
        if (treeBadCount == 1)
        {
            s = s + + treeBadCount + " tree that need changing";
        } 
        else
        {
            s = s + + treeBadCount + " trees that need changing";
        }

        printLine(s);

        s = s + "\n";
        printLine(s); 
        
        // Update global count
        totalGoodTreeCount += treeGoodCount;
        totalBadTreeCount += treeBadCount;
        
        return true;
    }
    
    public void printFinalCountData()
    {
        printLine("\n\n FINAL TREE COUNT\n");
        printLine("Number of good trees is " + totalGoodTreeCount);
        printLine("Number of BAD trees is " + totalBadTreeCount);
    }
       
    public void closeFile()
    {
        if (!initFlag)
        {
            return;
        }
    
        //flush stream
        try
        {
            output.flush();
        }
        catch (Exception e)
        {
            e.printStackTrace();  
            println("Exception error attempting to flush " + fname);
        }
    
        //close stream
        try
        {
            output.close();
        }
        catch (Exception e)
        {
            e.printStackTrace();  
            println("Exception error attempting to close " + fname);
            return;
        }
        println("Successfully closed file " + fname);
        return;
    }
    
    public boolean readInitFlag()
    {
        return initFlag;
    }
}