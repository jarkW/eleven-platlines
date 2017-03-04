class DisplayMgr
{
    boolean okFlag;
    final static int RED_TEXT =  #FF002B;
    boolean errsFlag;
   

    // Add in list of failed streets - can be display at the end when program ends
    // is street + reason why failed (missing L*, missing snaps)
    StringList failedStreets;
    StringList allFailedStreets; // Used for reporting at end
    
    String streetNameMsg;
    String itemNameMsg;
    
    // Needed e.g. for when prompting for QAPlatlines_config.json file and user enters invalid value - usual showErrMsg does not work because call back function?
    String savedErrMsg;
    boolean savedErrMsgToDisplay;
    
    // for testing - might need to use 'set' instead of 'image' - might use less memory
    // not implemented yet
    boolean USE_SET_FOR_DISPLAY = false;  
    
    final static int BACKGROUND = #D6D6D6;
    final static int STREET_FRAGMENT_WIDTH = 200;
    final static int STREET_FRAGMENT_HEIGHT = 200;
    
    // These contain the dimensions of the street on the screen - so can be cleared easily 
    float scaledStreetWidth;
    float scaledStreetHeight;
    int streetFragmentWidth;
    int streetFragmentHeight;
    int itemWidth;
    int itemHeight;
    
    
    public DisplayMgr()
    {
        okFlag = true;
        errsFlag = false;
        textSize(14);
        streetNameMsg = "";
        itemNameMsg = "";
        savedErrMsg = "";
        savedErrMsgToDisplay = false;
        failedStreets = new StringList();
        allFailedStreets = new StringList();
    }
    
    public void showInfoMsg(String info)
    {
        // clear existing text box
        clearTextBox(0, height - 50, width, 50);
        
        // print out message
        fill(50);
        textSize(14);
        // Want text to go along bottom - so set relative to height of display
        text(info, 10, height - 50, width, 50);  // Text wraps within text box
        printToFile.printDebugLine(this, "INFO MSG = " + info, 2);
    }
    
    public void showErrMsg(String info, boolean exitNow)
    {
        
        String s;
        clearDisplay();
        fill(RED_TEXT);
        textSize(16);
        
        s = "";
        
        if (exitNow)
        {
            s = "FATAL ERROR: ";
        }
          
        text(s, 10, 100, width-10, 80);  // Text wraps within text box
        if (info.length() > 0)
        {
            text(info, 10, 120, width-10, 80);
        }
        if (exitNow)
        {
            String s1 = "!!!!! EXITING WITH ERRORS !!!!!";
            if (workingDir.length() > 0)
            {
                s1 = s1 + workingDir + File.separatorChar + "debug_info.txt for more information";
            }
            text(s1, 10, 140, width-10, 80);
            text("Press q or x or ESC to close window", 10, 160, width-10, 80);
            printToFile.printDebugLine(this, "ERR MSG = FATAL ERROR: " + info + " exit now flag = " + exitNow, 3);
        }
        else
        {
            printToFile.printDebugLine(this, "ERR MSG = " + info + " exit now flag = " + exitNow, 3);
        }
        
        errsFlag = true;
    }
    
    public void showSuccessMsg()
    {
        
        String s;
        
        clearDisplay();
        fill(50);
        textSize(16);
        
        if (errsFlag)
        {
            // Just in case we flagged up a non-fatal error e.g. because not upload files to server - and so did not end the program at that point
            // User might have missed the brief red message
            s = "!!!! Errors detected, please check " + workingDir + File.separatorChar + "debug_info.txt and " + configInfo.readOutputFilename() + " for more information !!!!";
        }
        else
        {
            s = "!!!! SUCCESS - No errors detected, please check " + configInfo.readOutputFilename() + " for more information !!!!";
        }
        text(s, 10, 100, width-10, 80);  // Text wraps within text box
        text("Press q or x or ESC to close window", 10, 120, width-10, 80);
    }
            
    public void setStreetName(String streetName, String streetTSID, int streetNum, int totalStreets)
    {
        streetNameMsg = "Processing street " + streetName + " (" + streetTSID + "): " + streetNum + " of " + totalStreets;
    }
    
    public void showStreetName()
    {
        // clear existing text box
        clearTextBox(10, 10, width, 50);
        
        fill(50);
        textSize(14);
        // Want text to go along top - so set relative to width of display
        text(streetNameMsg, 10, 10, width, 50);  // Text wraps within text box
    }
    
    public void showStreetProcessingMsg()
    {
        String s = "Drawing trees and platlines for " + streetNameMsg;
        
        // clear existing text box
        clearTextBox(10, 30, width, 50);
        
        fill(50);
        textSize(12);
        // Want text to go along top - so set relative to width of display
        text(s, 10, 30, width, 50);  // Text wraps within text box
    }
     
      
    public void showStreetImage(PImage streetImage, String streetImageName)
    {
        // scale down the street so fits in bottom of window
        float maxWidth;
        float maxHeight;
        float scalar;
        
       // clear the previous image
        clearImage(50, height - 50 - int(scaledStreetHeight), int(scaledStreetWidth), int(scaledStreetHeight));
        
        // Need to change the location/size of snap depending on whether it is a wide or tall street
        // DO WE NEED THIS - COULD JUST ALWAYS MAKE THE SAME HEIGHT, THEN NOT HAVING TO FIDDLE WITH ITEM POSITION
        
        if (streetImage.width > streetImage.height)
        {
           // scale down the wide street so fits in bottom of window
           maxWidth = width-100;
           maxHeight = 200;      
           scalar = maxWidth / streetImage.width;
        
           scaledStreetWidth = maxWidth;
           scaledStreetHeight = streetImage.height * scalar;
            if (scaledStreetHeight > maxHeight)
            {
                scalar = maxHeight / scaledStreetHeight;
                scaledStreetHeight = maxHeight;
                scaledStreetWidth = scaledStreetWidth * scalar;
            }
        }
        else
        {
           // scale down the tall street so fits in bottom of window
           maxWidth = width-100;
           maxHeight = height - 400;      
           scalar = maxHeight / streetImage.height;
        
           scaledStreetHeight= maxHeight;
           scaledStreetWidth = streetImage.width * scalar;
           
           if (scaledStreetWidth > maxWidth)
            {
                scalar = maxWidth / scaledStreetWidth;
                scaledStreetWidth = maxWidth;
                scaledStreetHeight = scaledStreetHeight * scalar;
            }
        }
        
        image(streetImage, 50, height - 50 - int(scaledStreetHeight), scaledStreetWidth, scaledStreetHeight);
        showInfoMsg(streetImageName);
    }
                     
    public void clearDisplay()
    {
        // clear screen
        //background(230);
        fill(BACKGROUND);
        stroke(BACKGROUND);
        rect(0, 0, width, height); 
    }
    
    public void clearImage(int x, int y, int imageWidth, int imageHeight)
    {
        // This just creates an image which is the same size as the existing one ... and then draws it out in background colour
        PImage img = createImage(imageWidth + 1, imageHeight + 1, RGB);
        img.loadPixels();
    
        for (int i = 0; i< img.pixels.length; i++)
        {
            img.pixels[i] = BACKGROUND; 
        }

        //rect(50, height - 50, scaledSnapWidth, scaledSnapHeight);
        image(img, x, y, imageWidth, imageHeight);
    }
    
    public void clearTextBox(int x, int y, int boxWidth, int boxHeight)
    {
        // Clear text box - i.e. fill with background colour
        fill(BACKGROUND);
        stroke(BACKGROUND);
        rect(x, y, boxWidth, boxHeight); 
    }
    
    public void setSkippedStreetsMsg(String msg)
    {
        failedStreets.append(msg);
    }
    
    public boolean showAllSkippedStreetsMsg()
    {
        String s;
        clearDisplay();
        fill(50);
        textSize(16);
        
        if (allFailedStreets.size() == 0)
        {
            s = "All streets were successfully processed";
            text(s, 10, 100, width-10, 80);  // Text wraps within text box
            return true;
        }
        else
        {
            s = "The following streets were not processed";
        }

        text(s, 10, 100, width-10, 80);  // Text wraps within text box
        int i;
        for (i = 0; i < allFailedStreets.size(); i++)
        {
            text(allFailedStreets.get(i), 10, 120 + (i * 20), width-10, 80);
        }
        i = i + 10;
        text("Press 'x' to exit", 10, 120 + (i * 20), width-10, 80);
        
        return false;
        
    }
    
    public void showThisSkippedStreetMsg(boolean errorFlag)
    {
        clearDisplay();
        fill(50);
        textSize(16);
                
        if (failedStreets.size() == 0)
        {
            return;
        }
        //String s = "The following streets were not processed";
        if (errorFlag)
        {
            fill(RED_TEXT);
        }
        else
        {
            fill(50);
        }
        //text(s, 10, 100, width-10, 80);  // Text wraps within text box
        
        // Print out each of the messages for this street ... and save to the total message buffer for reporting at end of run
        int i;
        for (i = 0; i < failedStreets.size(); i++)
        {
            text(failedStreets.get(i), 10, 120 + (i * 20), width-10, 80);
            allFailedStreets.append(failedStreets.get(i));
        }
        i = i + 10;
        //text("Errors during initial processing of street - press 'c' to continue, 'x' to exit", 10, 120 + (i * 20), width-10, 80);
        
        // Now that all messages have been given for this street - clear the message buffer        
        failedStreets = new StringList();
    }
    
    public boolean checkIfFailedStreetsMsg()
    {
        if (failedStreets.size() == 0)
        {
            return false;
        }
        return true;
    }
    
    public void setSavedErrMsg(String errMsg)
    {
        savedErrMsg = errMsg;
        savedErrMsgToDisplay = true;
    }
    
    public void showSavedErrMsg()
    {
        if (savedErrMsgToDisplay)
        {
            showErrMsg(savedErrMsg, true);
        }
    }
}