import java.nio.*; //for formatting byte buffers
import java.io.ByteArrayOutputStream; //for formatting byte buffers
import processing.net.*; //for talking to the DAC over the network

class EtherDream {

    Client dacClient; //the etherdream we'll be talking to
    //one strategy for getting responses
    byte[] data; //a byte array to store incoming data
    //variable for another strategy for getting responses
    byte [] responseData = new byte[22];
    //variable for a third strategy for getting responses
    byte [] firstData = new byte[1];//we want to read our first byte to make sure it's the right character before we fill up the buffer with the rest of the stuff
    byte [] restOfData = new byte[21];


    int theMinX = -15600; //the min and max of our drawable range...for mapping things from screen coordinates
    int theMaxX = 15600;
    int theMinY = -15600;
    int theMaxY = 15600;

    //data that is set by dac responses
    //initially set with dummy values until we get the first message
    char ackChar = 'x';
    String ackString = " ";
    char commandSent = ' ';
    int protocol = 0;
    int lightEngineState =0;
    int playbackState = 0;
    int source = 0;
    int flags = 0;
    int playbackFlags = 0;
    int sourceFlags = 0;
    int bufferFullness = 0;
    int pointRate = 0;
    int pointCount = 0;

    EtherDream() { //class constructor doesn't do anything
    }

    void startSocket(PApplet theSketch, String theIPAddress, int thePort) { //initialize our serial communication
        dacClient = new Client(theSketch, theIPAddress, thePort); //setup a new client
    }



    void readResponse() { //very complicated attempt number three for reading data from the DAC
        while(dacClient.available() == 0) {
            delay(1);
        }
        if (dacClient.available() > 0) { // If there's incoming data from the client...
            int rd = dacClient.readBytes(firstData);//read the first byte
            if (rd == 1) {
                if (isACKorNAK(firstData[0])) { //see if the first byte looks right
                    //println(char(subset(data,0,2)));
                    int rod = dacClient.readBytes(restOfData);//if it is, get the rest of the data
                    ByteArrayOutputStream combinedStream = new ByteArrayOutputStream( ); //use a byte stream to combine those two bits of data into one
                    try {
                        combinedStream.write(firstData);
                        combinedStream.write(restOfData);
                    }
                    catch (IOException e) {
                        println("=========OUTPUT STREAM EXCEPTION=======");
                        e.printStackTrace();
                    }
                    byte [] combinedData = combinedStream.toByteArray( ); //take that combined data and convert it from a byte buffer to a byte array
                    parseResponse(combinedData); //parse that data and use it to set all of our dac variables
                } else { //if the first character wasn't an ACK or NAK signal
                    boolean foundCorrectData = false;
                    for (int i = 0; i<restOfData.length; i++) { //loop through the rest of the data in search of an ack or nak character
                        if (isACKorNAK(restOfData[i]) ) {//if we found it
                            byte[] td1 = subset(restOfData, i, restOfData.length - i);//take the rest of that array
                            byte[] td2 = new byte[22 - restOfData.length - i];//and read the number of elements from the stream that would finish a 22 byte array
                            int rtd = dacClient.readBytes(td2);//fill the above buffer
                            ByteArrayOutputStream combinedStream2 = new ByteArrayOutputStream( ); //use a byte buffer to combine these two byte arrays int one
                            try {
                                combinedStream2.write(td1);
                                combinedStream2.write(td2);
                            }
                            catch (IOException e) {
                                println("=========OUTPUT STREAM EXCEPTION=======");
                                e.printStackTrace();
                            }
                            byte [] combinedData2 = combinedStream2.toByteArray( ); //convert byte buffer back to array
                            foundCorrectData = true;
                            parseResponse(combinedData2);//parse the data and set appropriate variables
                        }
                    }//end for rest of data
                    if (foundCorrectData) {
                        println("FIXED A BAD BUFFER WITH A GHETTO METHOD");
                    } else {
                        println("DIDN'T FIND THE RIGHT ACK IN THE REST OF THE ARRAY EITHER");
                    }
                } //end else ackornak not first data
            } //end if rd == 1
            else {
                println("READING FIRST BYTE, BUT GOT MORE THAN ONE BYTE!!!!");
            }
        }
    }

    /*
    //method no. two for reading responses, much more simple...
     void readResponse() {
     
     int rd = dacClient.readBytes(responseData); //read the number of bytes necessary to fill this byte array with 22 spots.
     //if (rd<0) {
     //premature EOF
     //break;
     // }
     if (rd == 22) {
     parseResponse(responseData);
     }
     }
     */

    /*
//method number one for reading responses from the DAC
     void readResponse() {
     boolean withoutResponse = true;
     //println("WAITING FOR RESPONSE...");
     //while(withoutResponse){
     if (dacClient.available() > 0) { // If there's incoming data from the client...
     data = dacClient.readBytes(); // ...then grab it all?
     //println(char(subset(data,0,2)));
     
     parseResponse(data); //parse the response and set dac variables
     //withoutResponse =false;
     }
     }
     }
     */

    void clearResponses() { //haven't used this yet...doesn't seem to help
        dacClient.clear();
    }

    boolean isACKorNAK(byte theByte) { //given a byte, return true if it is a valid ACK or NAK character and not some random garabage.
        boolean isItSomethingWeKnow = false;
        if (theByte == byte('a') || theByte == byte('F') || theByte == byte('I') || theByte == byte('!')) {
            isItSomethingWeKnow = true;
        } else {
            isItSomethingWeKnow = false;
        }
        return isItSomethingWeKnow;
    }


    void parseResponse(byte [] data) {
        ByteBuffer bb = ByteBuffer.wrap(data);
        bb.order(ByteOrder.LITTLE_ENDIAN);
        ackChar = char(bb.get(0));
        boolean validAckChar = true;
        if (ackChar == 'a') {
            ackString = "ACK";
        } else if (ackChar == 'F') {
            ackString = "Full NAK";
            println("FULL NAK");
        } else if (ackChar == 'I') {
            ackString = "Invalid NAK";
            println("INVALID NAK");
        } else if (ackChar == '!') {
            ackString = "Stop Condition NAK";
        } else {
            println("INVALID FIRST CHARACTER IN DATA STREAM" + "Data Stream Length:    " + data.length);
            validAckChar = false;
        }
        if (validAckChar) {
            if (data.length == 22) { //if we're receiving the right kind of packet
                commandSent = char(bb.get(1));
                protocol = int(bb.get(3));
                lightEngineState = int(bb.get(3));//int(bb.getShort(3));
                playbackState = int(bb.get(4));
                source = int(bb.get(5));
                flags = int(getUnsignedShort(bb, 6));
                playbackFlags = int(getUnsignedShort(bb, 8));
                sourceFlags = int(getUnsignedShort(bb, 10));
                bufferFullness = int(getUnsignedShort(bb, 12));
                pointRate = bb.getInt(14);
                pointCount = bb.getInt(18);
                if(ackChar != 'a') println("INVALID COMMAND SENT: " + commandSent + "   " + ackString  + " playState: " + playbackState + " lightState: " + lightEngineState);
                //printStatus();
            } else {
                println("INVALID DATA LENGTH:    " + data.length);
            }
        }
    }

    void printStatus() { //print the dac status variables to the console
        println("Status: " + ackString);
        println("Command Sent: " + commandSent);
        println("Protocol:    " + protocol);
        println("Light Engine State: " + lightEngineState);
        println("Playback State: " + playbackState);
        println("Source: " + source);
        println("Flags: " + flags);
        println("Playback Flags: " + playbackFlags);
        println("Source Flags: " + sourceFlags);
        println("Buffer Fullness: " + bufferFullness);
        println("Point Rate: " + pointRate);
        println("Point Count: " + pointCount);
    }

    void sendTestPoints() { //send two manually hard coded points a number of times...this function isn't use at the moment.
        int numPoints = 200;
        ByteBuffer headerData = ByteBuffer.allocate(3);
        headerData.order(ByteOrder.LITTLE_ENDIAN);
        headerData.put(byte('d'));
        putUnsignedShort(headerData, numPoints);
        byte[] ptHeader = headerData.array();     
        //test if we can make anything work by drawing a line where one end is your mouse
        //x and y range are from -32768 to +32767.    Jacob recommends mapping to 50 percent or less to protect galvos from too-wide-scanning
        //color ranges are from 0 to 65535


        //OUR ANCHOR POINT
        int x = (int) map(width*.1, 0, width, -16000, 16000);
        int y = (int) map(height/2, 0, height, 16000, -16000); //invert the mapping because processing is upside down
        int r = (int) map(100, 0, 255, 0, 65535);
        int g = (int) map(20, 0, 255, 0, 65535);
        int b = (int) map(20, 0, 255, 0, 65535);
        int i = -1;
        int u1 = 0;
        int u2 = 0;
        int flag = 0;
        byte[] pt1 = packPoint(x, y, r, g, b, i, u1, u2, flag);

        //OUR MOUSE POINT USES MOSTLY THE SAME DATA
        int mX = (int) map(width*.9, 0, width, -16000, 16000);
        int mY = (int) map(height/2, 0, height, -16000, 16000); //invert the mapping because processing is "upside down"
        byte[] pt2 = packPoint(mX, mY, r, g, b, i, u1, u2, flag); //swapped r and g data to see if line has gradient color


        //CONCATENATE ALL OF OUR DATA INTO ONE BYTE ARRAY (HEADER AND POINT INFO)
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );
        try {
            outputStream.write(ptHeader);

            //have tried writing a bunch of points to the buffer, image stays up slightly longer with:
            for (int j = 0; j<100; j++) {
                outputStream.write(pt1); //write one point to the buffer
                outputStream.write(pt2); //write the second point to the buffer
            }
        } 
        catch (IOException e) {
            println("=========OUTPUT STREAM EXCEPTION=======");
            e.printStackTrace();
        }

        byte [] message = outputStream.toByteArray();
        dacClient.write(message); 
        readResponse();
    }

    int [] sendPolylineSubset(ArrayList<ArrayList<PVector>> thePoints, ArrayList<Integer> theColors, int lineIndex, int ptIndex, int count) {
        //given an arraylist of "polylines" (which are in turn an arraylist of vertices, a list of colors and a startint curve/index/quantity, send some points to the dac
        int [] terminatingIndices = new int[2];
        int ptQuantity =    getVertexCount(thePoints); //get the number of points to draw
        // println("POINT QUANITY:"    + ptQuantity);
        ByteBuffer headerData = ByteBuffer.allocate(3);
        headerData.order(ByteOrder.LITTLE_ENDIAN);
        headerData.put(byte('d'));
        putUnsignedShort(headerData, count);
        byte[] ptHeader = headerData.array(); //create a header byte array that tells the DAC how many points to draw
        //CONCATENATE ALL OF OUR DATA INTO ONE BYTE ARRAY (HEADER AND POINT INFO)
        int theMeasuredCount = 0;

        ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );
        try {
            outputStream.write(ptHeader);
            int intensity = -1;
            int u1 = 0;
            int u2 = 0;
            int flag = 0;
            boolean firstI = true;
            boolean firstJ = true;

            while (theMeasuredCount < count) { //keep repeating until we've sent as many points as necessary
                for (int i = 0; i<thePoints.size (); i++) {
                    if (firstI) {
                        i = lineIndex; //update the position of our loop to match our subset starting point on the first move
                        firstI = false;
                    } else {
                        for (int j = 0; j<thePoints.get (i).size(); j++) {
                            if (firstJ) {
                                j = ptIndex; //update the position of our vertex loop to match our subset starting point on the first move
                                firstJ = false;
                            } else {
                                if (theMeasuredCount<count) {
                                    PVector thePt = thePoints.get(i).get(j);
                                    int x = (int) map(thePt.x, 0, width, theMinX, theMaxX);
                                    int y = (int) map(thePt.y, 0, height, theMaxY, theMinY); //invert the mapping because processing is upside down
                                    if (x < theMinX) {
                                        x = theMinX;
                                    }
                                    if (x > theMaxX) {
                                        x = theMaxX;
                                    }
                                    if (y < theMinY) {
                                        y = theMinY;
                                    }
                                    if (y > theMaxY) {
                                        y = theMaxY;
                                    }

                                    int r1 = (theColors.get(i) >> 16) & 0xFF;    // Faster way of getting red(argb) from our color
                                    int g1 = (theColors.get(i)>> 8) & 0xFF;     // Faster way of getting green(argb) from our color
                                    int b1 = theColors.get(i) & 0xFF;                    // Faster way of getting blue(argb) from our color
                                    int r = (int) map(r1, 0, 255, 0, 65535);
                                    int g = (int) map(g1, 0, 255, 0, 65535);
                                    int b = (int) map(b1, 0, 255, 0, 65535);
                                    byte[] tempPt = packPoint(x, y, r, g, b, intensity, u1, u2, flag);
                                    outputStream.write(tempPt); //write one point to the buffer
                                    pointsSent++;
                                    theMeasuredCount++; //increment our counter for the number of points we have sent
                                    if (theMeasuredCount == count) {
                                        if (j< thePoints.get(i).size()-2) { //if we ended in the middle of a polyline that still has points in it
                                            terminatingIndices[0] = i;
                                            terminatingIndices[1] = j+1;
                                        } else if (i < thePoints.size()-1) { //if we ended at the end of a polyline, and there is another polyline after this one
                                            terminatingIndices[0] = i+1;
                                            terminatingIndices[1] = 0;
                                        } else { //if we ended on the last point of the last polyline, we'll start at the start of the first one next time
                                            terminatingIndices[0] = 0;
                                            terminatingIndices[1] = 0;
                                        }
                                        //set our starting index for the next sending cycle
                                    }
                                }
                            }
                        }//end for all points in a polyline
                    }
                }//end for all polylines
            }//end while count not yet met
        } //end try
        catch (IOException e) {
            println("=========OUTPUT STREAM EXCEPTION=======");
            e.printStackTrace();
        }//end catch

        byte [] message = outputStream.toByteArray();
        dacClient.write(message);
        readResponse();
        println("SENT POLYLINE SUBSET=====================  :    " + theMeasuredCount);
        return terminatingIndices;
        // printStatus();
    }


    void sendPolylines(ArrayList<ArrayList<PVector>> thePoints, ArrayList<Integer> theColors) {
        //send all the vertices/colors in an arraylist of polylines
        int ptQuantity =    getVertexCount(thePoints); //get the number of points to draw
        // println("POINT QUANITY:"    + ptQuantity);
        ByteBuffer headerData = ByteBuffer.allocate(3);
        headerData.order(ByteOrder.LITTLE_ENDIAN);
        headerData.put(byte('d'));
        putUnsignedShort(headerData, ptQuantity);
        byte[] ptHeader = headerData.array(); //create a header byte array that tells the DAC how many points to draw
        //CONCATENATE ALL OF OUR DATA INTO ONE BYTE ARRAY (HEADER AND POINT INFO)

        ByteArrayOutputStream outputStream = new ByteArrayOutputStream( );
        try {
            outputStream.write(ptHeader);
            int intensity = -1;
            int u1 = 0;
            int u2 = 0;
            int flag = 0;
            for (int i = 0; i<thePoints.size (); i++) {
                for (int j = 0; j<thePoints.get (i).size(); j++) {
                    PVector thePt = thePoints.get(i).get(j);
                    int x = (int) map(thePt.x, 0, width, -15600, 15600);
                    int y = (int) map(thePt.y, 0, height, -15600, 15600); //invert the mapping because processing is upside down
                    int r1 = (theColors.get(i) >> 16) & 0xFF;    // Faster way of getting red(argb) from our color
                    int g1 = (theColors.get(i)>> 8) & 0xFF;     // Faster way of getting green(argb) from our color
                    int b1 = theColors.get(i) & 0xFF;                    // Faster way of getting blue(argb) from our color
                    int r = (int) map(r1, 0, 255, 0, 65535);
                    int g = (int) map(g1, 0, 255, 0, 65535);
                    int b = (int) map(b1, 0, 255, 0, 65535);
                    byte[] tempPt = packPoint(x, y, r, g, b, intensity, u1, u2, flag);
                    outputStream.write(tempPt); //write one point to the buffer
                    //pointsSent++;
                }//end for all points in a polyline
            }//end for all polylines
        } //end try
        catch (IOException e) {
            println("=========OUTPUT STREAM EXCEPTION=======");
            e.printStackTrace();
        }//end catch

        byte [] message = outputStream.toByteArray();
        dacClient.write(message);
        readResponse();
        println("SENT POLYLINE POINTS=====================");
        // printStatus();
    }

    void begin() {
        int lwm = 0; //according to protocol, "low water mark" set to zero
        int rate = 30000; //our rate to read from the buffer
        println("Sending begin command...");
        ByteBuffer begData = ByteBuffer.allocate(7);
        begData.order(ByteOrder.LITTLE_ENDIAN);
        begData.put(byte('b'));
        putUnsignedShort(begData, lwm);
        putUnsignedInt(begData, rate);
        byte[] begDataArray = begData.array();        
        dacClient.write(begDataArray);
        readResponse();
    }//end begin

    //send begin command
    void begin(int rate) {
        int lwm = 0; //according to protocol, "low water mark" set to zero
        //int rate = 30000; //our rate to read from the buffer
        println("Sending begin command...");
        ByteBuffer begData = ByteBuffer.allocate(7);
        begData.order(ByteOrder.LITTLE_ENDIAN);
        begData.put(byte('b'));
        putUnsignedShort(begData, lwm);
        putUnsignedInt(begData, rate);
        byte[] begDataArray = begData.array();        
        dacClient.write(begDataArray);
        readResponse();
    }//end begin

    //SEND "UPDATE" COMMAND
    void update(int rate) {
        int lwm = 0; //according to protocol, "low water mark" set to zero
        println("Sending update command...");
        ByteBuffer begData = ByteBuffer.allocate(7);
        begData.order(ByteOrder.LITTLE_ENDIAN);
        begData.put(byte('u'));
        putUnsignedShort(begData, lwm);
        putUnsignedInt(begData, rate);
        byte[] begDataArray = begData.array();        
        dacClient.write(begDataArray);
        readResponse();
    }

    // Emergency stop
    void eStop() {
        dacClient.write(byte('s'));
        readResponse();
    }

    // Clears emergency stop state
    void clearStop() {
        dacClient.write(byte('c'));
        readResponse();
    }

    // Prepare data stream
    void prepare() {
        dacClient.write(byte('p'));
        readResponse();
        println("PREPARED=====================");
        //printStatus();
    }

    // Ping
    void ping() {
        dacClient.write(byte('?'));
        readResponse();
        //println("PING=====================");
        //printStatus();
    }



    byte [] packPoint(int theX, int theY, int theR, int theG, int theB, int theI, int theU1, int theU2, int theFlags) {
        //adapted from python code at: https://github.com/j4cbo/j4cDAC/blob/master/tools/tester/dac.py 
        //Pack some color values into a struct dac_point.
        //Values must be specified for x, y, r, g, and b. If a value is not
        //passed in for the other fields, i will default to max(r, g, b); the 
        //rest default to zero.
        if (theI < 0) {
            theI = max(theR, theG, theB);
        }
        ByteBuffer dat = ByteBuffer.allocate(18);
        dat.order(ByteOrder.LITTLE_ENDIAN);
        putUnsignedShort(dat, theFlags);
        dat.putShort((short) theX);
        dat.putShort((short) theY);
        putUnsignedShort(dat, theR);
        putUnsignedShort(dat, theG);
        putUnsignedShort(dat, theB);
        putUnsignedShort(dat, theI);
        putUnsignedShort(dat, theU1);
        putUnsignedShort(dat, theU2);
        byte[] datArray = dat.array();
        return datArray;
    }
}//end DAC class 
//==========================================END DAC CLASS====================================
//==========================================END DAC CLASS====================================
//==========================================END DAC CLASS====================================


//============================================EXTRA FUNCTIONS========================
void putUnsignedShort(ByteBuffer bb, int value) {
    //from http://stackoverflow.com/questions/9883472/is-it-possible-to-have-an-unsigned-bytebuffer-in-java
    bb.putShort((short) (value & 0xffff));
}

void putUnsignedInt(ByteBuffer bb, int value) {
    //from http://stackoverflow.com/questions/9883472/is-it-possible-to-have-an-unsigned-bytebuffer-in-java
    bb.putInt((int) (value & 0xffffffffL));
}

public static int getUnsignedShort(ByteBuffer bb, int position) {
    //from http://stackoverflow.com/questions/9883472/is-it-possible-to-have-an-unsigned-bytebuffer-in-java
    return (bb.getShort(position) & 0xffff);
}


String parseBytesString(byte data[]) {
    //return a formatted string which allows us to print out the binary data of a byte array
    String val = "-1";
    String[] binArray = new String[data.length];
    for (int i = 0; i < data.length; i++) {
        binArray[i] = binary(data[i]);
    }
    val = join(binArray, ":");
    return val;
}


String parseBytesHexString(byte data[]) {
    //return a formatted string which allows us to print out the hex data of a byte array
    String val = "-1";
    String[] binArray = new String[data.length];
    for (int i = 0; i < data.length; i++) {
        binArray[i] = hex(data[i]);
    }
    val = join(binArray, ":");
    return val;
}