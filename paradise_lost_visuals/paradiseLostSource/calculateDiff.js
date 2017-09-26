var xSplit = 3;
var ySplit = 3;
var numRegions = xSplit*ySplit;
inlets = 1;
outlets = numRegions;

var templateMatrix = new JitterMatrix(jsarguments[1]);
var whiteMatrix = new JitterMatrix("white");
var blackMatrix = new JitterMatrix("black");
var copyMatrix = new JitterMatrix(1, "char", xDim, yDim);
var thresholdMatrix = new JitterMatrix("threshVal");
var xDim = thresholdMatrix.dim[0];
var yDim = thresholdMatrix.dim[1];


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



function mod(number, modulus){ return ((number%modulus)+modulus)%modulus}	
fl = Math.floor;
function calculateRegionalDiff(){
	matrixHistory[historyInd].frommatrix(thresholdMatrix);
	for(var k = 0; k < numRegions; k++){
		historyRegionDiffs[historyInd][k] = 0;
	}
	for(var i = 0; i < xDim; i++){
		for(var j = 0; j < yDim; j++) {
			var regionInd = fl(i / fl(xDim/xSplit)) * xSplit + fl(j / fl(yDim/ySplit));
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
		calculateRegionalDiff()
		post("Calculated");
		post();
		calculationOccuring = false;
	}
	for(var i = 0; i < numRegions; i++) {
		outputMatricies[i].setall(historyRegionDiffs[historyInd][i])
		//outlet(i, historyRegionDiffs[historyInd][i]);
		outlet(i, "jit_matrix", outputMatricies[i].name);
		post(historyRegionDiffs[historyInd][i], i, historyInd);
		post();
	}
	historyInd = mod(historyInd+1, historyRegionDiffs.length);
}