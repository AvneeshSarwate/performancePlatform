//=========================================FUNCTIONS==================================================
//=========================================FUNCTIONS==================================================
//=========================================FUNCTIONS==================================================


//===============================GENERATE POLYGONS=================================================
//===============================GENERATE POLYGONS=================================================
///generate an n-sided polygon with a given centerpoint, radius and rotation angle
ArrayList<PVector> generatePolygon(float x, float y, float radius, float rotationAngle, int npoints) {
    float angle = TWO_PI / npoints;
    ArrayList<PVector> pVertices = new ArrayList<PVector>();
    PVector theFirstPoint = new PVector();
    for (float a = 0; a < TWO_PI; a += angle) {

        float sx = x + cos(a+rotationAngle) * radius;
        float sy = y + sin(a+rotationAngle) * radius;
        PVector pVertex = new PVector(sx, sy);
        pVertices.add(pVertex);
        if (a == 0) { //if we're on the first point, save it so we can add it at the end to get a closed curve
            theFirstPoint = pVertex;
        }
    }
    pVertices.add(theFirstPoint); //close the curve
    if (pVertices.size() != npoints +1) {
        println("GOAL VERTEX COUNT DOESN'T MATCH ACTUAL VERTEX COUNT...SOMETHING IS WRONG WITH THE GENERATE POLYGON FUNCTION");
    }
    return pVertices;
}
//===============================END GENERATE POLYGONS=================================================
//===============================END GENERATE POLYGONS=================================================

//===============================GET DRAWING LENGTH=================================================
//===============================GET DRAWING LENGTH=================================================
///return the total "drawing length" of a two dimensional arraylist of polyline vertices, considering a starting and ending point and travel between lines
float drawingLength(ArrayList<ArrayList<PVector>> theDrawing, PVector frameStartPt, PVector frameEndPt) {
    float travelDist = 0; //store our total drawing distance
    travelDist += frameStartPt.dist(theDrawing.get(0).get(0)); //add the distance from the start to the start of the first line
    travelDist += frameEndPt.dist(theDrawing.get(theDrawing.size()-1).get(theDrawing.get(theDrawing.size()-1).size()-1)); //add the distance to the end of the last line
    for (int i = 0; i<theDrawing.size (); i++) { //for each polyline, get the length, and the distance from the endpoint to the start of the next polyline
        if (i != theDrawing.size()-1) {
            //if we aren't on the last polyline, get the distance from the end of this one to the start of the next one
            travelDist += theDrawing.get(i).get(theDrawing.get(i).size()-1).dist(theDrawing.get(i+1).get(0));
        }
        travelDist += polylineLength(theDrawing.get(i)); //get the length of the polyline
    }
    return travelDist;
}
//===============================END GET DRAWING LENGTH=================================================
//===============================END GET DRAWING LENGTH=================================================


//===============================GET SINGLE POLYLINE LENGTH=================================================
//===============================GET SINGLE POLYLINE LENGTH=================================================
float polylineLength(ArrayList<PVector> pLine) {
    float theLength = 0;
    if (pLine.size() >1) {
        for (int i = 1; i<pLine.size (); i++) {
            theLength += pLine.get(i).dist(pLine.get(i-1));
        }//if we have more than one vertex, add the length to the length list
    }
    return theLength; //return our curve length
}
//===============================END GET SINGLE POLYLINE LENGTH=================================================
//===============================END GET SINGLE POLYLINE LENGTH=================================================

//===============================GET VERTEX COUNT=================================================
//===============================GET VERTEX COUNT=================================================
int getVertexCount(ArrayList<ArrayList<PVector>> theDrawing) {
    //returns the total amount of vertices in an array of polylines
    int vertexSize = 0;
    for (int i = 0; i<theDrawing.size (); i++) {
        for (int j = 0; j<theDrawing.get (i).size(); j++) {
            vertexSize++;
        }
    }
    return vertexSize;
}
//===============================END GET VERTEX COUNT=================================================
//===============================END GET VERTEX COUNT=================================================

//===============================DRAW POLYLINES=================================================
//===============================DRAW POLYLINES=================================================
void drawPolylineArrayList(ArrayList<ArrayList<PVector>> theDrawing, ArrayList<Integer> theColor, int theLineWeight, int theVertexWeight) {

    //draw our polylines
    for (int i = 0; i<theDrawing.size (); i++) {
        noFill();
        strokeWeight(theLineWeight);
        if (theDrawing.size() == theColor.size()) {//if out list of colors matches our list of lines
            stroke(theColor.get(i));
        } else {
            stroke(255, 0, 0);//just make everything red
        }
        beginShape();
        for (int j = 0; j< theDrawing.get (i).size(); j++) {
            vertex(theDrawing.get(i).get(j).x, theDrawing.get(i).get(j).y);
        }
        endShape();
    }
    //end draw our polylines


    //draw our polyline vertices for debugging
    for (int i = 0; i<theDrawing.size (); i++) {
        int r = 0;
        int g = 0;
        int b = 0;
        color alphaColor = color(255, 0, 0);
        noFill();
        strokeWeight(theVertexWeight);
        if (theDrawing.size() == theColor.size()) {//if out list of colors matches our list of lines
            //stroke(theColor.get(i));
            r = (theColor.get(i) >> 16) & 0xFF;    // Faster way of getting red(argb)
            g = (theColor.get(i)>> 8) & 0xFF;     // Faster way of getting green(argb)
            b = theColor.get(i) & 0xFF;                    // Faster way of getting blue(argb)
            alphaColor = color(r, g, b, 150);
            stroke(alphaColor);
        } else {
            stroke(255, 0, 0);//just make everything red
        }
        beginShape(POINTS);
        for (int j = 0; j< theDrawing.get (i).size(); j++) {

            //stroke(alphaColor);
            //strokeWeight(theVertexWeight*2 * float(j)/float(theDrawing.get(i).size()));
            vertex(theDrawing.get(i).get(j).x, theDrawing.get(i).get(j).y);
        }
        endShape();
    }
}//end draw polyline arraylist funciton
//===============================END DRAW POLYLINES=================================================
//===============================END DRAW POLYLINES=================================================

//===============================REGENERATE POLYLINE ARRAYLIST WITH FIXED VERTEX QUANITY=================================================
//===============================REGENERATE POLYLINE ARRAYLIST WITH FIXED VERTEX QUANITY=================================================
PolylineColor rebuildPolylines(ArrayList<ArrayList<PVector>> polylinesToDraw, ArrayList<Integer> colors, int numBufferPoints, int endPointDwell, int vertexDwell, float drawToTransferRatio, PVector frameStartPt, PVector frameEndPt) {
    float transferDist = 0;
    float totalPolylineLength = 0;
    int innerVertexCount = 0; //how many vertices do we have in all of our polylines, not including endpoints?
    transferDist += frameStartPt.dist(polylinesToDraw.get(0).get(0)); //add the distance from the start to the start of the first line
    transferDist += frameEndPt.dist(polylinesToDraw.get(polylinesToDraw.size()-1).get(polylinesToDraw.get(polylinesToDraw.size()-1).size()-1)); //add the distance to the end of the last line
    for (int i = 0; i<polylinesToDraw.size (); i++) { //for each polyline, get the length, and the distance from the endpoint to the start of the next polyline
        if (polylinesToDraw.get(i).size() > 2) {
            innerVertexCount += polylinesToDraw.get(i).size() -2;
        }
        if (i != polylinesToDraw.size()-1) {
            //if we aren't on the last polyline, get the distance from the end of this one to the start of the next one
            transferDist += polylinesToDraw.get(i).get(polylinesToDraw.get(i).size()-1).dist(polylinesToDraw.get(i+1).get(0));
        }
        totalPolylineLength += polylineLength(polylinesToDraw.get(i)); //get the length of the polyline
    }
    //println(transferDist,totalPolylineLength);
    float factoredTotalLength = transferDist*drawToTransferRatio + totalPolylineLength; //get the factored length of our drawing and transfers
    int numFreeBufferPoints = numBufferPoints - (polylinesToDraw.size()*endPointDwell); //subtract the end point dwelling from our buffer, as we will always need it
    numFreeBufferPoints -= innerVertexCount*vertexDwell; //the number of points left over for interpolation and tranfering after drawing our endpoints and vertices
    if (numFreeBufferPoints < 0) {
        println("===================DRAWING DATA TOO DENSE REDUCE CURVE COUNT, POLYLINE DENSITY OR DWELL===========================");
    }
    float lengthPerVertex = factoredTotalLength/float(numFreeBufferPoints);
    //println("Number of free buffer points:    " + numFreeBufferPoints);
    //println(lengthPerVertex);

    ArrayList<ArrayList<PVector>> rebuiltPolylinesToDraw = new ArrayList<ArrayList<PVector>>(); //create a new empty list to store our polylines to draw and the transfers
    ArrayList<Integer> rebuiltColors = new ArrayList<Integer>(); //you can't make an arraylist of colors, so we're using integer as a holder.    Stores the color of each polyline, and the color 0,0,0 for transfers
    ArrayList<PVector> tempTransferVertices = new ArrayList<PVector>();
    float startTransferSize = frameStartPt.dist(polylinesToDraw.get(0).get(0)); //add the distance from the start to the start of the first line
    int startTransferVertexAllotment = floor(startTransferSize*drawToTransferRatio / lengthPerVertex); //how many vertices are allowed for this transfer?
    float startTransferStepSize = startTransferSize / float(startTransferVertexAllotment); //how big are our subdivisions for this line segment?
    for (int i = 0; i<startTransferVertexAllotment; i++) {
        PVector interpolatedStartTransferPt = PVector.lerp(frameStartPt, polylinesToDraw.get(0).get(0), i*startTransferStepSize/startTransferSize);
        tempTransferVertices.add(interpolatedStartTransferPt);
    }
    rebuiltPolylinesToDraw.add(tempTransferVertices); //add our first transfer to our array of polylines
    rebuiltColors.add(color(0, 0, 0)); //add a blank transfer color to our array of colors for each polyline

    //rebuild polylines and add transfer subdivisions
    for (int i = 0; i<polylinesToDraw.size (); i++) {

        if (i > 0) { //if we aren't on the first polyline, we need to transfer from the end of the last one to the start of our current one
            ArrayList<PVector> tempBetweenCrvVertices = new ArrayList<PVector>();
            PVector currentStartPt = polylinesToDraw.get(i).get(0);
            PVector lastEndPt = polylinesToDraw.get(i-1).get(polylinesToDraw.get(i-1).size()-1);
            float xferSize = lastEndPt.dist(currentStartPt); //the distance from the end of the last to the start of the current line

            int xferVertexAllotment = floor(xferSize*drawToTransferRatio / lengthPerVertex); //how many vertices are allowed for this transfer?
            float xferStepSize = xferSize / float(xferVertexAllotment); //how big are our subdivisions for this line segment?
            for (int j = 1; j<xferVertexAllotment; j++) {
                PVector interpolatedXferPt = PVector.lerp(lastEndPt, currentStartPt, j*xferStepSize/xferSize);
                tempBetweenCrvVertices.add(interpolatedXferPt);
            }
            rebuiltPolylinesToDraw.add(tempBetweenCrvVertices); //add our first transfer to our array of polylines
            rebuiltColors.add(color(0, 0, 0)); //add a blank transfer color to our array of colors for each polyline
        }


        ArrayList<PVector> tempVertices = new ArrayList<PVector>();
        if (polylinesToDraw.get(i).size() > 2) { //if it is a line or a polyline that we are drawing
            int vertexAllotment = floor(polylineLength(polylinesToDraw.get(i))/lengthPerVertex); //how many vertices we need to add to this curve
            //println("vertexAllotment:    " + vertexAllotment) ;
            int actualAddedVertexCount = 0;    //store the amount of vertices we have added so we can see if it matches the allotted count
            for (int j = 0; j<polylinesToDraw.get (i).size(); j++) {//for each vertex in our selected polyline
                if (j>0) { //if we are not on the first point, see if we need to add vertices between our current position and the last one
                    float segmentLength = polylinesToDraw.get(i).get(j).dist(polylinesToDraw.get(i).get(j-1));
                    if (segmentLength>lengthPerVertex) { //if we're of a certain size, add vertices
                        int numAddedVertices = round(segmentLength/lengthPerVertex) - 1;
                        if (numAddedVertices>0) { //if we actually need to add vertices
                            for (int k = 0; k<numAddedVertices; k++) {
                                PVector segmentInterpolatedVertex = PVector.lerp(polylinesToDraw.get(i).get(j-1), polylinesToDraw.get(i).get(j), float(k+1)/float(numAddedVertices+1)); //get the interpolated point
                                tempVertices.add(segmentInterpolatedVertex); //add the interpolated point to the index
                                actualAddedVertexCount += 1; //store how many vertices we have added
                            }//end for num added Vertices
                        }//end if numadded vertices greater than zero
                    }//end if segment length>length per vertex
                    if (j != polylinesToDraw.size()-1) { //if we aren't on the last vertex, but are on    pre-existing vertex, add the vertex dwell
                        for (int k = 0; k<vertexDwell; k++) {
                            tempVertices.add(polylinesToDraw.get(i).get(j)); //add the vertex dwell
                        }//for each counter in our vertex dwell
                    }//if we're on any vertex but the last or first
                }//end if j>0            
                if (j == 0 || j == polylinesToDraw.size()-1) { //if we are on the endpoints, add our dwell number of points to the array of vertices
                    for (int k = 0; k<endPointDwell; k++) {
                        tempVertices.add(polylinesToDraw.get(i).get(j));
                    }//add points at the endpoints of the line
                }
            }//end fora each vertex in the given polyline.

            //println("Actual Vertex Count: " + actualAddedVertexCount + " Goal Vertex Count: " + vertexAllotment);
        } //end if is line with more than two points
        else if (polylinesToDraw.size() == 1) {//if our polyline is a point (one value long)
            for (int j = 0; j<endPointDwell; j++) {
                tempVertices.add(polylinesToDraw.get(i).get(0));
            }
        }
        rebuiltPolylinesToDraw.add(tempVertices);
        rebuiltColors.add(colors.get(i));    //add the polyline color to the new color array
    } //end for each polyline

    ArrayList<PVector> endTransferVertices = new ArrayList<PVector>();
    PVector theEndPt = polylinesToDraw.get(polylinesToDraw.size()-1).get(polylinesToDraw.get(polylinesToDraw.size()-1).size()-1);
    float endTransferSize = frameStartPt.dist(theEndPt); //add the distance from the end to the end of the last line
    int endTransferVertexAllotment = floor(endTransferSize*drawToTransferRatio / lengthPerVertex); //how many vertices are allowed for this transfer?
    float endTransferStepSize = endTransferSize / float(endTransferVertexAllotment); //how big are our subdivisions for this line segment?
    for (int i = 0; i<endTransferVertexAllotment; i++) {
        PVector interpolatedEndTransferPt = PVector.lerp(theEndPt, frameEndPt, (i+1)*endTransferStepSize/endTransferSize);
        endTransferVertices.add(interpolatedEndTransferPt);
    }
    rebuiltPolylinesToDraw.add(endTransferVertices); //add our first transfer to our array of polylines
    rebuiltColors.add(color(0, 0, 0)); //add a blank transfer color to our array of colors for each polyline

    int totalVertexCount = getVertexCount(rebuiltPolylinesToDraw);

    if (totalVertexCount < numBufferPoints) {
        int lastPolylineSize = 0;
        PVector theLastBlankPt = new PVector();
        while (lastPolylineSize < 1) {
            int lastPolylineIndex = rebuiltPolylinesToDraw.size()-1;
            lastPolylineSize = rebuiltPolylinesToDraw.get(lastPolylineIndex).size();
            if (lastPolylineSize>0) {
                theLastBlankPt =    rebuiltPolylinesToDraw.get(lastPolylineIndex).get(lastPolylineSize-1);    //get the last point in the buffer
            }
            else{
                rebuiltPolylinesToDraw.remove(rebuiltPolylinesToDraw.size()-1); //remove the last empty curve
                rebuiltColors.remove(rebuiltColors.size()-1); //remove the last empty color curve too
            }
        }

        for (int i = 0; i< numBufferPoints - totalVertexCount; i++) {
            rebuiltPolylinesToDraw.get(rebuiltPolylinesToDraw.size()-1).add(theLastBlankPt); //add some blank points to the end to make our buffer size right...
        }
    } else if (totalVertexCount > numBufferPoints) {
        //println("GENERATED TOO MANY VERTEX POINTS.    DELETING SOME! EXPECT BUGS...");
        for (int i = 0; i> totalVertexCount - numBufferPoints; i++) {
            int randomIndex = int(random(rebuiltPolylinesToDraw.size()-1));
            int randomVertexIndex = int(random(rebuiltPolylinesToDraw.get(randomIndex).size()));
            rebuiltPolylinesToDraw.get(randomIndex).remove(randomVertexIndex); //delete random points until our buffer size is small enough
        }
    }

    int rebuiltVertexCount = getVertexCount(rebuiltPolylinesToDraw);
    if (rebuiltVertexCount != numBufferPoints) {
        //println("Incorrect Rebuilt Vertex Count = " + rebuiltVertexCount);
    }
    PolylineColor result = new PolylineColor(rebuiltPolylinesToDraw, rebuiltColors);
    return result;
}

//===============================POLYLINE COLOR CLASS=================================================
//===============================POLYLINE COLOR CLASS=================================================
class PolylineColor {

    ArrayList<ArrayList<PVector>> vertexMatrix;
    ArrayList<Integer> colorList;


    PolylineColor(ArrayList<ArrayList<PVector>> matrixOfVtx, ArrayList<Integer> listOfColor) {
        vertexMatrix = matrixOfVtx;
        colorList = listOfColor;
    }

    ArrayList<ArrayList<PVector>> vertexMatrix() {
        return vertexMatrix;
    }

    ArrayList<Integer> colorList() {
        return colorList;
    }
}