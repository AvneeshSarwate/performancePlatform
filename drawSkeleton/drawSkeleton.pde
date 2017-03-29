import oscP5.*;
import netP5.*;
  
OscP5 oscP5;

ArrayList<ArrayList<PVector>> originalPolylinesToDraw = new ArrayList<ArrayList<PVector>>();    //a 2D arraylist to store our polyline vertices
ArrayList<Integer> originalColors = new ArrayList<Integer>(); //you can't make an arraylist of colors, so we're using integer as a holder.
ArrayList<ArrayList<PVector>> rebuiltPolylines = new ArrayList<ArrayList<PVector>>(); 
ArrayList<Integer> rebuiltColorList =    new ArrayList<Integer>();
ArrayList<ArrayList<ArrayList<PVector>>> skeletonFrames = new ArrayList<ArrayList<ArrayList<PVector>>>();
ArrayList<ArrayList<PVector>> newestFrame = new ArrayList<ArrayList<PVector>>();
int numBufferPts = 600;
int endPtDwell = 5;
int vtxDwell = 5;
PVector frameStartPoint, frameEndPoint;
float rotAngle = 0;
float drawToXferRatio = .5; //our drawing interpolation should be smaller than our transfer interpolation
boolean stream = false; //don't send to the dac until we tell you to (with the spacebar)
boolean started = false; //we need to send some stuff only once at the beginning
//ArrayList<color> polylineColors = new ArrayList<color>();
int nextStreamLineIndex = 0; //the location where we should start the subset to send
int nextStreamVertexIndex = 0; //he location where we should start the subset to send
int pointsSent = 0;
//=================================NETWORKING DATA===========================================================================
String ipAddress = "192.168.0.20"; //set the ip address of the DAC
int port = 7765; //set the port of the DAC
EtherDream dac; //make a new instance of the etherdream class called dac

boolean usingDac= true;
boolean drawingSkeleton = true;

void setup() {
    size(640, 360);
    frameStartPoint = new PVector(width/2, height/2);
    frameEndPoint = new PVector(width/2, height/2);

    oscP5 = new OscP5( this , 12000 );

    dac = new EtherDream();
    if(usingDac) dac.startSocket(this, ipAddress, port); //connect to the DAC (must be on the same network)
    delay(500);
    if(usingDac) dac.readResponse();

    //dac.printStatus();
}

//=========================================DRAW==================================================
//=========================================DRAW==================================================
//=========================================DRAW==================================================

void draw() {
    //println("FRAMERATE:    " + frameRate);
    // dac.readResponse();
    //dac.printStatus();
    
    ///////////////////////GENERATE SHAPES TO DRAW AS AN ARRAYLIST, WITH A MATCHING ARRAYLIST OF COLORS AND FORMAT FOR DESIRED VERTEX COUNT////////
    originalPolylinesToDraw.clear(); //clear the shapes from our arraylist
    originalColors.clear(); //clear the color of our shapes
    rebuiltPolylines.clear();
    rebuiltColorList.clear();
    background(100);
    float scaleShape = map(frameCount%50, 0, 50, 0, TWO_PI);//float(frameCount%1000 )/ 1000.0);
    scaleShape = map(cos(scaleShape), 0, 1, .005, .3);
    //float rotAngle = 0;
    ArrayList<PVector> t1 = generatePolygon(width/1.5, height/2, min(width, height)*.4, rotAngle, 3);
    ArrayList<PVector> c1 = generatePolygon(width/1.5, height/2, min(width, height)*.3, rotAngle, 10);
    ArrayList<PVector> p1 = generatePolygon(mouseX, mouseY, min(width, height)*scaleShape, rotAngle, 5);
    ArrayList<PVector> h1 = generatePolygon(width/1.5, height/2, min(width, height)*.1, rotAngle, 4);
    originalPolylinesToDraw.add(t1);
    originalPolylinesToDraw.add(c1);
    originalPolylinesToDraw.add(p1);
    originalPolylinesToDraw.add(h1);

    //make our colors
    color red = color(60, 0, 0);
    color green = color(0, 60, 0);
    color blue = color(0, 0, 60);
    originalColors.add(red);
    originalColors.add(green);
    originalColors.add(blue);
    if(!drawingSkeleton) originalColors.add(green);
    //draw our polylines
    // drawPolylineArrayList(polylinesToDraw,colors,2,6);
    // float drawingLength = drawingLength(polylinesToDraw, new PVector(width/2, height/2), new PVector(width/2, height/2));
    // println(drawingLength);
    //drawPolylineArrayList(rebuiltPolylinesToDraw, rebuiltColors, 1, 6);
    if(drawingSkeleton) originalPolylinesToDraw = new ArrayList<ArrayList<PVector>>(newestFrame);
    if(originalPolylinesToDraw.size() > 0) {
        PolylineColor rebuiltData = rebuildPolylines(originalPolylinesToDraw, originalColors, numBufferPts, endPtDwell, vtxDwell, drawToXferRatio, frameStartPoint, frameEndPoint);
        rebuiltPolylines = rebuiltData.vertexMatrix;
        rebuiltColorList = rebuiltData.colorList;
        drawPolylineArrayList(rebuiltPolylines, rebuiltColorList, 1, 6);
    }
    
    ////////////////////////////SEND STUFF TO THE DAC/////////////////////////////////////////////////
    if(usingDac) dac.printStatus();
    if (stream && usingDac) { //if we have been told to stream
        if (dac.ackChar != 'a') { //if we have a NAK character, we need to reset things, so turn off "started" so we can send the prepare/begin command again.
            started = false;
            //dac.begin(40000);
        }
        if (!started) {
            if (dac.playbackState == 2) {
                println("already playing!");
            } else if (dac.playbackState == 0) {
                dac.prepare(); //send the prepare command
                dac.printStatus();
            } else {
                println("INVALID DAC STATE AT PREPARE");
            }
        }
        int cap = 1799 - dac.bufferFullness; //find how much space is left between the max buffer capacity and the current number of points in the buffer
        //if (cap > numBufferPts) {
        println("============BUFFER FULLNESS:    " + dac.bufferFullness + " ============");
        //dac.sendPolylines(rebuiltPolylines, rebuiltColorList);
        int theCountToSend = min(cap, numBufferPts); //calculate the numbef of points to send, the minimum between the number wanted and the number that we have
        int [] theIndexResponse = dac.sendPolylineSubset(rebuiltPolylines, rebuiltColorList, nextStreamLineIndex, nextStreamVertexIndex, theCountToSend); //given a 2d arraylist of vertices, send the requested subset
        nextStreamLineIndex = theIndexResponse[0]; //what curve number comes next?
        nextStreamVertexIndex = theIndexResponse[1]; //what vertex comes immediately after the one we just sent (for next time)?
        //dac.sendPolylines(originalPolylinesToDraw, originalColors);
        //println("SENDING VALUES");
        //}

        if (!started) { //if it's the first time around
            //dac.sendPolylines(rebuiltPolylines, rebuiltColorList); //double send to get the buffer more full at start
            dac.begin(10000);//start the DAC at this point rate
            started = true;//set to true so that it only happens once.
            println("STARTING STREAM");
        }
    }
    if(usingDac) dac.ping(); //ping the DAC so that we know how many points are in the buffer next time we go through the draw loop
}//end draw


void oscEvent( OscMessage m ) {
  print( "Received an osc message" );
  print( ", address pattern: " + m.getAddress( ) );
  println( ", typetag: " + m.getTypetag( ) );
  if(m.getAddress( ).equals("/skeletonFrame")) {
    ArrayList<PVector> arms = new ArrayList<PVector>();
    ArrayList<PVector> headLeg = new ArrayList<PVector>();
    ArrayList<PVector> lastLeg = new ArrayList<PVector>();
    ArrayList<ArrayList<PVector>> frame = new ArrayList<ArrayList<PVector>>();
    StringBuilder debugFrame = new StringBuilder(" ");
    
    for(int i = 0; i < 16; i+=2){
        int x = Math.round(map(m.floatValue(i), 0, 32, 0, width));
        int y = Math.round(map(m.floatValue(i+1), 0, 32, 0, height));
        debugFrame.append(x + " " + y);
        arms.add(new PVector(x, y));
    }
    for(int i = 16; i < 32; i+=2){
        int x = Math.round(map(m.floatValue(i), 0, 32, 0, width));
        int y = Math.round(map(m.floatValue(i+1), 0, 32, 0, height));
        debugFrame.append(x + " " + y);
        headLeg.add(new PVector(x, y));
    }
    
    //special point added to connect last leg to hip
    int xH = Math.round(map(m.floatValue(22), 0, 32, 0, width));
    int yH = Math.round(map(m.floatValue(23), 0, 32, 0, height));
    debugFrame.append(xH + " " + yH);
    lastLeg.add(new PVector(xH, yH));
    
    for(int i = 32; i < 40; i+=2){
        int x = Math.round(map(m.floatValue(i), 0, 32, 0, width));
        int y = Math.round(map(m.floatValue(i+1), 0, 32, 0, height));
        debugFrame.append(x + " " + y);
        lastLeg.add(new PVector(x, y));
    }

    frame.add(arms);
    frame.add(headLeg);
    frame.add(lastLeg);
    newestFrame = frame;
    println(debugFrame);
    //skeletonFrames.add(frame);
  }
  println();
}


//=============================================KEYPRESSES============================================
//=============================================KEYPRESSES============================================
//=============================================KEYPRESSES============================================

void keyPressed() {
    if (key == CODED) {
        //up and down keyboard keys rotate the shapes drawn on the screen
        if (keyCode == UP) {
            rotAngle += .05;
            rotAngle = rotAngle%TWO_PI;
        } else if (keyCode == DOWN) {
            rotAngle -= .05;
            if (rotAngle < 0) {
                rotAngle = TWO_PI + rotAngle;
            }
            rotAngle = rotAngle%TWO_PI;
        }
    }

    if (key == 's' || key == 'S') {
        dac.eStop(); //stop the laser
    }
    if (key == 'c' || key == 'C') {
        dac.clearStop(); //clear emergency stop
    }
    if (key == 'p' || key == 'P') {
        dac.prepare();
    }
    if (key == '?' || key == '/') {
        dac.ping();
        dac.printStatus();
    }
    if (key == 'b' || key == 'B') {
        dac.begin();
        dac.printStatus();
    }
    if (key == 'f' || key == 'F') {
        dac.sendTestPoints();
        dac.printStatus();
    }
    if (key == 'd' || key == 'D') {
        dac.sendPolylines(rebuiltPolylines, rebuiltColorList);
    }
    if (key == ' ') {
        stream = true;
    }
    if (key == 'x' || key == 'X') {
        stream = false;
        started = false;
    }
}