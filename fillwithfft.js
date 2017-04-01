inlets = 5;
outlets = 1;

var templateMatrix = new JitterMatrix(jsarguments[1]);
var whiteMatrix = new JitterMatrix("white");
var blackMatrix = new JitterMatrix("black");
var xDim = templateMatrix.dim[0];
var yDim = templateMatrix.dim[1]
var copyMatrix = new JitterMatrix(1, "char", xDim, yDim);
var exprTemplate = "";
var exprParams = new Array(inlets);
var exprObj = new JitterObject("jit.expr");
var patternMatrices = new Array();
var patternXdim = 32;
var patternYdim = 32;
for(var i = 0; i < 6; i++) {
	patternMatrices.push(new JitterMatrix("pattern"+(i+1)));
}
var fftList = new Array(300);
for(var i = 0; i < fftList.length; i++){
		fftList[i] = 0;
}
var fftThreshold = 80;

var points = new Array();
var noiseGrainSize = 20;
var whiteNoise = true;
var pNoise = 0.5;
points.push([xDim/2, yDim/2]);


function ryojiNoise() {
	//post(copyMatrix.dstdimstart.length);
	//post(copyMatrix.dstdimend);
	var old_dstdimstart = copyMatrix.dstdimstart;
	var old_dstdimend = copyMatrix.dstdimend;
	copyMatrix.usedstdim = 1;
	
	var numCols = 21;
	var c = 11;
	var colWidth = xDim/numCols;
	
	for(var i = 0; i < xDim; i += colWidth){
		
		var colInd = i/colWidth + 1;
		var heightMult = c - Math.abs(c-colInd);
		var colHeight = 10 * heightMult;

		for(var j = 0; j < yDim; j += colHeight){
			copyMatrix.dstdimstart = [i, j];
			copyMatrix.dstdimend = [i+colWidth, j+colHeight];
			var colCellInd = j/colHeight;
			var fftRange = Math.floor(fftList.length / (yDim/colHeight));
			var fftWeight = fftSegmentWeight(colCellInd*fftRange, (colCellInd+1)*fftRange);
			var condition = fftWeight > fftThreshold;
			var color = Math.random() > 0.5 ? blackMatrix : whiteMatrix;
			copyMatrix.frommatrix(color);
		}
	}
	copyMatrix.dstdimstart = old_dstdimstart;
	copyMatrix.dstdimend = old_dstdimend;
	copyMatrix.usedstdim = 0;	
}

function fftSegmentWeight(startInd, endInd){
	var sum = 0;
	for(var i = startInd; i < endInd; i++){
		sum += fftList[i];
	}
	//post(startInd);
	//post(endInd);
	//post(sum);
	//post(1.0*sum/(endInd-startInd))
	//post();
	return 1.0*sum/(endInd-startInd);
}

function bang(){
	//copyMatrix.op("pass", templateMatrix);
	//zeroFill(0.5);
	//calcExpr()
	//randomPatternTiling();
	//fftPatternTiling();
	//ryojiNoise();
	noiseGrain();
	outlet(0, "jit_matrix", copyMatrix.name);
}

function grainSize(val){
	noiseGrainSize = Math.max(6, Math.round(val));
	post(noiseGrainSize);
	post();
}

function list(){
	for(var i = 0; i < Math.min(arguments.length, fftList.length); i++){
		fftList[i] = arguments[i];
	}
}

function randomPatternTiling(){

	//post(copyMatrix.dstdimstart.length);
	//post(copyMatrix.dstdimend);
	var old_dstdimstart = copyMatrix.dstdimstart;
	var old_dstdimend = copyMatrix.dstdimend;
	copyMatrix.usedstdim = 1;
	for(var i = 0; i < xDim; i += patternXdim){
		for(var j = 0; j < yDim; j += patternYdim){
			
			copyMatrix.dstdimstart = [i, j];
			copyMatrix.dstdimend = [i+patternXdim, j+patternYdim];
			var ind = Math.floor(Math.random()*6);
			copyMatrix.frommatrix(patternMatrices[ind]);
		}
	}
	copyMatrix.dstdimstart = old_dstdimstart;
	copyMatrix.dstdimend = old_dstdimend;
	copyMatrix.usedstdim = 0;
}


function fftPatternTiling(){

	//post(copyMatrix.dstdimstart.length);
	//post(copyMatrix.dstdimend);
	var old_dstdimstart = copyMatrix.dstdimstart;
	var old_dstdimend = copyMatrix.dstdimend;
	copyMatrix.usedstdim = 1;
	for(var i = 0; i < xDim; i += patternXdim){
		for(var j = 0; j < yDim; j += patternYdim){
			var fftBinInd = (i/patternXdim) * (yDim/patternYdim) + j/patternYdim;
			var binVal = fftList[fftBinInd];
			copyMatrix.dstdimstart = [i, j];
			copyMatrix.dstdimend = [i+patternXdim, j+patternYdim];
			var ind = binVal > fftThreshold ? 0 : 3;
			copyMatrix.frommatrix(patternMatrices[ind]);
		}
	}
	copyMatrix.dstdimstart = old_dstdimstart;
	copyMatrix.dstdimend = old_dstdimend;
	copyMatrix.usedstdim = 0;
}


function msg_int(val){
	if(inlet > 0) {
		exprParams[inlet] = val;
		post("yo");
		calcExprTemplate();
		post();
	}
}

function fftThresh(val) {
	fftThreshold = val;
}

function msg_float(val){
	if(inlet > 0) {
		exprParams[inlet] = val;
	}
}

function expr(val) {
	post(val);
	post();
	exprTemplate = val;
}

function calcExprTemplate() {
	var finalExpr = exprTemplate;
	post(finalExpr);
	post();
	for(var i = 1; i < inlets; i++) {
		var numOccurences = allOccurences(finalExpr, "$"+i).length
		for(var j = 0; j < numOccurences; j++) {
			finalExpr = finalExpr.replace("$"+i, exprParams[i]);
		}
	}
	post(finalExpr);
	post();
	return finalExpr;
}

function calcExpr() {
	exprObj.expr = calcExprTemplate();
	exprObj.matrixcalc(copyMatrix, copyMatrix);
}

function allOccurences(mainString, subString){
	var occurences = new Array();
	var ind = mainString.indexOf(subString);
	while(ind != -1){
		occurences.push(ind);
		ind = mainString.indexOf(subString, ind+1);
	}
	return occurences;
}

function zeroFill(pFill) {
	for(var i = 0; i < xDim; i ++){
		for(var j = 0; j < yDim; j++) {
			var val = templateMatrix.getcell(i, j);
			if(val != 0) {
				if(Math.random() < pFill) {
					copyMatrix.setcell2d(i, j, 0);
				}
			}
		}
	}
	
}

function dist(x1, y1, x2, y2){
	return Math.pow(Math.pow(Math.abs(x1-x2), 2) + Math.pow(Math.abs(y1-y2), 2), 0.5);
}

function noiseGrain() {
	var old_dstdimstart = copyMatrix.dstdimstart;
	var old_dstdimend = copyMatrix.dstdimend;
	copyMatrix.usedstdim = 1;
	var screenDist = dist(0, 0, xDim, yDim);
	var localGrainSize = noiseGrainSize;
	for(var i = 0; i < xDim; i+=localGrainSize){
		for(var j = 0; j < yDim; j+=localGrainSize) {
			copyMatrix.dstdimstart = [i, j];
			copyMatrix.dstdimend = [i+localGrainSize, j+localGrainSize];
			var distRatio = dist(points[0][0], points[0][1], i+localGrainSize/2, j+localGrainSize/2) / screenDist;
			var colors = whiteNoise ? [whiteMatrix, blackMatrix] : [blackMatrix, whiteMatrix];
			var color = Math.random() > 0.5 ? colors[0] : colors[1];
			copyMatrix.frommatrix(color);
		}
	}
	copyMatrix.dstdimstart = old_dstdimstart;
	copyMatrix.dstdimend = old_dstdimend;
	copyMatrix.usedstdim = 0;
}