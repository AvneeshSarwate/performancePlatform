var xSplit = 3;
var ySplit = 3;
var numRegions = xSplit*ySplit;
inlets = 1;
outlets = numRegions + 1;

var templateMatrix = new JitterMatrix(jsarguments[1]);
var whiteMatrix = new JitterMatrix("white");
var blackMatrix = new JitterMatrix("black");
var copyMatrix = new JitterMatrix(1, "char", xDim, yDim);
var thresholdMatrix = new JitterMatrix("threshVal");
var xDim = thresholdMatrix.dim[0];
var yDim = thresholdMatrix.dim[1];
var diffThreshold = 0;
var diffScaleVal = 1;
var regionSize = xDim / xSplit * yDim / ySplit;
var useBinaryOutput = 0;


var matrixHistory = [];
var historyRegionDiffs = [];

var historyLen = 10;
for(var i = 0; i < historyLen; i++) {
	matrixHistory.push(new JitterMatrix(1, "char", xDim, yDim));
	historyRegionDiffs.push([]);
	for(var k = 0; k < numRegions; k++){
		historyRegionDiffs[i].push(0);
	}
}
var historyInd = 0;
var outputMatricies = [];
for(var k = 0; k < numRegions; k++){
	outputMatricies.push(new JitterMatrix(1, "char", 1, 1));
}

function diffThresh(thresh){
	diffThreshold = thresh;
}

function diffScale(scale) {
	diffScaleVal = scale;
}

function binaryOutput(useBin) {
	useBinaryOutput = useBin;
	post(useBinaryOutput);
	post();
}

function mod(number, modulus){ return ((number%modulus)+modulus)%modulus}	

var fl = Math.floor;

function calculateRegionalDiff(){
	matrixHistory[historyInd].frommatrix(thresholdMatrix);
	for(var k = 0; k < numRegions; k++){
		historyRegionDiffs[historyInd][k] = 0;
	}
	for(var i = 0; i < xDim; i++){
		for(var j = 0; j < yDim; j++) {
			var regionInd = fl(j / fl(yDim/ySplit)) * ySplit + fl(i / fl(xDim/xSplit));
			var lastHistoryInd = mod(historyInd-1, historyRegionDiffs.length);
			var pixelDiff = Math.abs(matrixHistory[lastHistoryInd].getcell(i, j) - thresholdMatrix.getcell(i,j))/255;
			//post(pixelDiff, i, j);
			//post();
			historyRegionDiffs[historyInd][regionInd] += pixelDiff;
		}
	}
}


var calculationOccuring = false;

function bang(){
	if(!calculationOccuring) {
		calculationOccuring = true;
		calculateRegionalDiff();
		calculationOccuring = false;
	}
	var regionValues = [];
	for(var i = 0; i < numRegions; i++) {
		var diffVal;
		if(useBinaryOutput) {
			diffVal = historyRegionDiffs[historyInd][i] > diffThreshold ? 255 : 0;
		} else {
			diffVal = historyRegionDiffs[historyInd][i] / regionSize * diffScaleVal;
		}
		regionValues.push(diffVal);
		outputMatricies[i].setall(diffVal)
		//outlet(i, historyRegionDiffs[historyInd][i]);
		outlet(i, "jit_matrix", outputMatricies[i].name);
		//post(historyRegionDiffs[historyInd][i], i, historyInd);
		//post();
	}
	outlet(xSplit*ySplit, rowMajorCellblockList(regionValues, xSplit, ySplit));
	historyInd = mod(historyInd+1, historyRegionDiffs.length);
}

function rowMajorCellblockList(vals, xSplit, ySplit){
	var coordVals = [];
	for(var i = 0; i < vals.length; i++){
		coordVals.push(fl(i/ySplit));
		coordVals.push(i%xSplit);
		coordVals.push(vals[i]);
	}
	return coordVals;
}