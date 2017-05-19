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
	phases[i] = 0;
	hitIndexes[i] = 0;
}
var blockFill = 0.5;

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
			var hitBlockStart = xDim * (phases[i] + patterns[i][j]);
			var hitBlockEnd = hitBlockEndCalc(hitBlockStart, i, j);
			drawBlock(i, hitBlockStart, hitBlockEnd, hitIndexes[i] == j ? greyMatrix : blackMatrix);
			var spaceBlockEnd = xDim * (phases[i] + patterns[i][j+1*patterns[i].length]);
			drawBlock(i, hitBlockEnd+1, spaceBlockEnd, whiteMatrix);
		}
	}
	copyMatrix.dstdimstart = old_dstdimstart;
	copyMatrix.dstdimend = old_dstdimend;
	copyMatrix.usedstdim = 0;
}

function hitBlockEndCalc(hitBlockStart, patInd, hitInd){
	var i = patInd;
	var j = hitInd;
	var hitBlockEnd = hitBlockStart + ( xDim * 
		(Math.max(patterns[i][j+1]%patterns[i].length, 1) - patterns[i][j])  * blockFill);
	return hitBlockEnd
}

function drawBlock(row, blockStart, blockEnd, colorMatrix){
	//if normal start/end
	if(blockStart < blockEnd && 0 < blockStart && blockEnd < xDim){
		copyMatrix.dstdimstart = [i, blockStart];
		copyMatrix.dstdimend = [i, blockEnd];
		copyMatrix.frommatrix(colorMatrix);
	} else 
	//if frameEnd < start < end
	if(xDim < blockStart && blockStart < blockEnd ){
		copyMatrix.dstdimstart = [i, blockStart%xDim];
		copyMatrix.dstdimend = [i, blockEnd%xDim];
		copyMatrix.frommatrix(colorMatrix);
	} else 
	//if start is in and end rolls over
	if(0 < blockStart && blockStart < xDim && xDim < blockEnd) {
		copyMatrix.dstdimstart = [i, blockStart];
		copyMatrix.dstdimend = [i, xDim];
		copyMatrix.frommatrix(colorMatrix);	
		copyMatrix.dstdimstart = [i, 0];
		copyMatrix.dstdimend = [i, blockEnd%xDim];
		copyMatrix.frommatrix(colorMatrix);	
	} else
	// if end < start (only way this should happen is blockStart%xDim < blockEnd)
	if(0 < blockEnd && blockEnd < xDim && blockEnd < blockStart) {
		copyMatrix.dstdimstart = [i, blockStart];
		copyMatrix.dstdimend = [i, xDim];
		copyMatrix.frommatrix(colorMatrix);	
		copyMatrix.dstdimstart = [i, 0];
		copyMatrix.dstdimend = [i, blockEnd%xDim];
		copyMatrix.frommatrix(colorMatrix);	
	} else {
		post("FUCK ERROR");
		post();
	}
}

function hitInfo(listVal){
	hitIndexes[listVal[0]] = listVal[1];
	phases[listVal[0]] = listVal[2];
}

function phaseVal(listVal){
	phases[listVal[0]] = phasesListVal[1];
}

function pattern(listVal){
	patterns[listVal[0]] = listVals.slice(1);
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
