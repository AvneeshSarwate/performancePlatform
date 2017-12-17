inlets = 5;
outlets = 1;

var templateMatrix = new JitterMatrix(jsarguments[1]);
var whiteMatrix = new JitterMatrix("white");
var blackMatrix = new JitterMatrix("black");
var greyMatrix = new JitterMatrix("grey");
var xDim = templateMatrix.dim[0];
var yDim = templateMatrix.dim[1];
var copyMatrix = new JitterMatrix(1, "char", xDim, yDim);
var numPat = 4;
var patterns = new Array(numPat);
var phases = new Array(numPat);
var hitIndexes = new Array(numPat);
for(var i = 0; i < numPat; i++) {
	patterns[i] = [];
	phases[i] = 0;
	hitIndexes[i] = 0;
}
var blockFill = 0.5;
var f = Math.floor;


function bang(){
	drawMatrix()
	outlet(0, "jit_matrix", copyMatrix.name);
}

function drawMatrix(){
	var old_dstdimstart = copyMatrix.dstdimstart;
	var old_dstdimend = copyMatrix.dstdimend;
	copyMatrix.usedstdim = 1;
	for(var i = 0; i < numPat; i++) {
		for(var j = 0; j < patterns[i].length; j++) {
			//post(i, j);
			var hitBlockStart = xDim * (phases[i] + patterns[i][j]);
			var hitBlockEnd = hitBlockEndCalc(hitBlockStart, i, j);
			var patLen = patterns[i].length;
			drawBlock(i, f(hitBlockStart), f(hitBlockEnd), hitIndexes[i] == j ? greyMatrix : blackMatrix, "hit");
			var spaceBlockEnd = xDim * (phases[i] + (patLen == j+1 ? 1 : patterns[i][j+1]));
			drawBlock(i, f(hitBlockEnd+1), f(spaceBlockEnd), whiteMatrix, "space");
		}
	}
	copyMatrix.dstdimstart = old_dstdimstart;
	copyMatrix.dstdimend = old_dstdimend;
	copyMatrix.usedstdim = 0;
}

function logData(){
	/*var p = 2;
	var starts = Array(patterns[p].length);
	var hitEnds = Array(patterns[p].length);
	for(var i = 0; i < starts.length; i++){
		starts[i] = xDim * (phases[p] + patterns[p][i]);
		post(xDim * (phases[p] + patterns[p][i]));
	}
	post();
	for(var i = 0; i < starts.length; i++){
		hitEnds[i] = hitBlockEndCalc(starts[i], p, i);
		post(hitBlockEndCalc(starts[i], p, i));
	}
	post();*/
	for(var i = 0; i < numPat; i++) {
		post(i);
		for(var j = 0; j < patterns[i].length; j++) {
			post(patterns[i][j]);
		}
		post();
	}
}

function hitBlockEndCalc(hitBlockStart, patInd, hitInd){
	var i = patInd;
	var j = hitInd;
	var patLen = patterns[i].length;
	var hitBlockEnd = hitBlockStart + ( xDim * 
		((patLen == j+1 ? 1 : patterns[i][j+1]) - patterns[i][j]) * blockFill);
	return hitBlockEnd;
}

//(Math.max(patterns[i][(j+1)%patterns[i].length], 1) - patterns[i][j]) 
function drawBlock(gridRow, blockStart, blockEnd, colorMatrix, usage){
	//if normal start/end;
	row = gridRow-1
	if( 0 <= blockStart && blockStart < blockEnd && blockEnd < xDim){
		copyMatrix.dstdimstart = [blockStart, row];
		copyMatrix.dstdimend = [blockEnd, row];
		copyMatrix.frommatrix(colorMatrix);
		//post("     normal", blockStart, blockEnd);
	} else 
	//if frameEnd < start < end
	if(xDim <= blockStart && blockStart < blockEnd ){
		copyMatrix.dstdimstart = [blockStart%xDim, row];
		copyMatrix.dstdimend = [blockEnd%xDim, row];
		copyMatrix.frommatrix(colorMatrix);
		//post("     frameEnd < start < end", blockStart, blockEnd);
	} else 
	//if start is in and end rolls over
	if(0 <= blockStart && blockStart < xDim && xDim <= blockEnd) {
		copyMatrix.dstdimstart = [blockStart, row];
		copyMatrix.dstdimend = [xDim, row];
		copyMatrix.frommatrix(colorMatrix);	
		copyMatrix.dstdimstart = [0, row];
		copyMatrix.dstdimend = [blockEnd%xDim, row];
		copyMatrix.frommatrix(colorMatrix);	
		//post("     start in, end rolls over", blockStart, blockEnd);
	} else {
		//post("FUCK ERROR");
		//post(blockStart);
		//post(blockEnd);
		//post(usage);
		//post(0 < blockEnd, blockEnd < xDim, blockEnd < blockStart, xDim);
		//post();
	}
}

function draw2(){
	var old_dstdimstart = copyMatrix.dstdimstart;
	var old_dstdimend = copyMatrix.dstdimend;
	copyMatrix.usedstdim = 1;
	
	copyMatrix.dstdimstart = [0, 0];
	copyMatrix.dstdimend = [200, 3];
	copyMatrix.frommatrix(whiteMatrix);
	
	copyMatrix.dstdimstart = old_dstdimstart;
	copyMatrix.dstdimend = old_dstdimend;
	copyMatrix.usedstdim = 0;
}

function hitInfo(){
	hitIndexes[arguments[0]] = arguments[1];
	//phases[arguments[0]] = arguments[2];
	//post(arguments[0], arguments[1], arguments[2]);
	//post();
}

function phaseVal(){
	phases[arguments[0]] = arguments[1];
}

function pattern(){
	//post(arguments[0]);post();
	var patList = new Array(arguments.length-1);
	for(var i = 0; i < patList.length; i++){
		patList[i] = arguments[i+1];
	}
	patterns[arguments[0]] = patList;
}

function list(listVals){
	
}

function msg_int(val){
	if(inlet > 0) {
		exprParams[inlet] = val;
		post("yo");
		calcExprTemplate();
		post();
	}
}

function msg_float(val){
	if(inlet > 0) {
		exprParams[inlet] = val;
	}
}
