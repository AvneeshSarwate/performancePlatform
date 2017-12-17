//define the grid regions to individually detect motion in
var xSplit = 3;
var ySplit = 3;
var numRegions = xSplit*ySplit;

inlets = 1;
outlets = numRegions + 2;

/*This is the thresholded matrix from the outer patch. I couldn't
find the way to get matrix input from an inlet so I used this 
hack instead - instead of processing output when a matrix message
is recieved, the script remembers this matrix and reads directly from
it on a bang. 
*/
var thresholdMatrix = new JitterMatrix("threshVal");
var xDim = thresholdMatrix.dim[0];
var yDim = thresholdMatrix.dim[1];

/*If calculating a binary value for whether movement has occured or not,
this variable is the threshold for the number of pixels that must be different.
This should probably be a ratio instead, but for now (TODO)*/
var diffThreshold = 70;


/*This flag determined whether motion was calculated as binary or continous*/
var useBinaryOutput = 0;

/*when the debugging continuous motion output, I wanted to normalize the 
output so that agressive motions would produce a 1 value. This variable 
is a simple scaling factor that I manually would adjust to acheive this.*/
var diffScaleVal = 7;

//size of a rectangular region
var regionSize = xDim / xSplit * yDim / ySplit;


/*I thought I would need to keep a history of the diffs for processing purposes
but I ended up not needing it. These are circular buffers that stores the 
last 10 frames and the regional motion values for the last 10 frames*/
var matrixHistory = [];
var historyRegionDiffs = [];

/*Initializing the circular buffers*/
var historyLen = 10;
for(var i = 0; i < historyLen; i++) {
	matrixHistory.push(new JitterMatrix(1, "char", xDim, yDim));
	historyRegionDiffs.push([]);
	for(var k = 0; k < numRegions; k++){
		historyRegionDiffs[i].push(0);
	}
}
var historyInd = 0;

/*To debug and scale the continuous motion output, I created one matrix
per region so I could look at greyscale values instead of numbers. These
are those matricies that are output*/
var outputMatricies = [];
for(var k = 0; k < numRegions; k++){
	outputMatricies.push(new JitterMatrix(1, "char", 1, 1));
}

//sets the binary movement pixel threshold
function diffThresh(thresh){
	diffThreshold = thresh;
}

//sets the scaling of continuous motion output
function diffScale(scale) {
	diffScaleVal = scale;
}
//sets whether the motion output is binary or continuous
function binaryOutput(useBin) {
	useBinaryOutput = useBin;
	post(useBinaryOutput);
	post();
}

//modulus function defined to wrap around both sides
function mod(number, modulus){ return ((number%modulus)+modulus)%modulus}	

//for convenience
var fl = Math.floor;

/*function for calculating the number of pixels that have changed per region*/
function calculateRegionalDiff(){
	matrixHistory[historyInd].frommatrix(thresholdMatrix);
	for(var k = 0; k < numRegions; k++){
		historyRegionDiffs[historyInd][k] = 0;
	}
	
	//iterate through the matrix pixels
	for(var i = 0; i < xDim; i++){
		for(var j = 0; j < yDim; j++) {
			
			//map the pixel to its region
			var regionInd = fl(j / fl(yDim/ySplit)) * ySplit + fl(i / fl(xDim/xSplit));
			
			//find the last frame's value
			var lastHistoryInd = mod(historyInd-1, historyRegionDiffs.length);
			
			//calculate whether the pixel has changed
			var pixelDiff = Math.abs(matrixHistory[lastHistoryInd].getcell(i, j) - thresholdMatrix.getcell(i,j))/255;
			
			//increment the region's diff count 
			historyRegionDiffs[historyInd][regionInd] += pixelDiff;
		}
	}
}

//variable that works as a "lock" to prevent overloading. not sure if necessary
var calculationOccuring = false;

function bang(){
	if(!calculationOccuring) {
		calculationOccuring = true;
		calculateRegionalDiff();
		calculationOccuring = false;
	}
	var regionValues = []; //the list to output of movement per region
	
	//for each region
	for(var i = 0; i < numRegions; i++) {
		var diffVal;
		
		//populate the list with either continuous or binary motion values
		if(useBinaryOutput) {
			diffVal = historyRegionDiffs[historyInd][i] > diffThreshold ? 255 : 0;
		} else {
			diffVal = historyRegionDiffs[historyInd][i] / regionSize * diffScaleVal;
		}
		regionValues.push(diffVal);
		
		//set output matrix to visualze region motion
		outputMatricies[i].setall(diffVal)
		
		//output matricies
		outlet(i, "jit_matrix", outputMatricies[i].name);
	}
	
	//output lists
	outlet(xSplit*ySplit, rowMajorCellblockList(regionValues, xSplit, ySplit));
	outlet(xSplit*ySplit+1, regionValues);
	historyInd = mod(historyInd+1, historyRegionDiffs.length);
}

//formats the output list into a list to fill a cellblock
function rowMajorCellblockList(vals, xSplit, ySplit){
	var coordVals = [];
	for(var i = 0; i < vals.length; i++){
		coordVals.push(fl(i/ySplit));
		coordVals.push(i%xSplit);
		coordVals.push(vals[i]);
	}
	return coordVals;
}