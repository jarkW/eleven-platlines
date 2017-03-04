class PNGFile
{
    // Used for both street snaps and item images
    String PNGImageName;  
    PImage PNGImage;
    int PNGImageHeight;
    int PNGImageWidth;
    
    boolean okFlag;
    
    public PNGFile(String fname)
    {
        okFlag = true;
         
        PNGImageName = fname;
        PNGImage = null;
    }
        
    public boolean setupPNGImage()
    {
        if (!loadPNGImage())
        {
            return false;
        }
 
        PNGImageWidth = PNGImage.width;
        PNGImageHeight = PNGImage.height;
        
        return true;
    }
    
    public boolean readOkFlag()
    {
        return okFlag;
    }
       
    public String readPNGImageName()
    {
        return PNGImageName;
    }
    
    public PImage readPNGImage()
    {
        return PNGImage;
    }   
    
    public int readPNGImageHeight()
    {
        return PNGImageHeight;
    }
    
    public int readPNGImageWidth()
    {
        return PNGImageWidth;
    }
    
    public boolean loadPNGImage()
    {
        // Load up item image
        String fullFileName;
        
        if (PNGImage != null)
        {
            // Image has already been loaded into memory
            return true;
        } 
        
        fullFileName = dataPath(PNGImageName);

        File file = new File(fullFileName);
        if (!file.exists())
        {
            printToFile.printDebugLine(this, "Missing file - " + fullFileName, 3);
            return false;
        }
                
        try
        {
            // load image
            PNGImage = loadImage(fullFileName, "png");
        }
        catch(Exception e)
        {
            println(e);
            printToFile.printDebugLine(this, "Fail to load image for " + PNGImageName, 3);
            return false;
        }         
        try
        {
            // load image pixels
            PNGImage.loadPixels();
        }
        catch(Exception e)
        {
            println(e);
            printToFile.printDebugLine(this, "Fail to load image pixels for " + PNGImageName, 3);
            return false;
        } 
        
        printToFile.printDebugLine(this, "Loading image from " + fullFileName + " with width " + PNGImage.height + " height " + PNGImage.width, 1);

        return true;
    }
    
    public void unloadPNGImage()
    {        
        memory.printUsedMemory("image unload start " + PNGImageName);
        if (PNGImage == null)
        {
            printToFile.printDebugLine(this, "!!!! Unloading null image " + PNGImageName, 3);
        }
        // workaround to remove memory leak - https://github.com/processing/processing/issues/1391.html#issuecomment-13356835
        g.removeCache(PNGImage);  
        
        PNGImage = null;
        printToFile.printDebugLine(this, "Unloading image " + PNGImageName, 1);
        // Need this to force the garbage collection to free up the memory associated with the image
        System.gc();
        memory.printUsedMemory("image unload end " + PNGImageName);
    }

}