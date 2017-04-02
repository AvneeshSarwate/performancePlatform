inlets = 5;
outlets = 1;

var templateMatrix = new JitterMatrix(jsarguments[1]);
var whiteMatrix = new JitterMatrix("white");
var blackMatrix = new JitterMatrix("black");
var xDim = templateMatrix.dim[0];
var yDim = templateMatrix.dim[1]
var copyMatrix = new JitterMatrix(1, "char", xDim, yDim);

var numVertLines = jsarguments[1] ? jsarguments[1] : 0;
var numHorLines = jsarguments[2] ? jsarguments[2] : 0;

var vLinePos =   [110, 650, 280, 780, 910];
var vLineSteps = [-5, 30, 100, -20, 70];
var vLineWidths  [10, 50, 100, 70, 150];
var p = [0, 4, 2, 3, 1];
var hLinePos = [vLinePos[p[0]], vLinePos[p[1]], vLinePos[p[2], vLinePos[p[3]], vLinePos[p[4]]];
var hLineSteps = [vLineSteps[p[0]], vLineSteps[p[1]], vLineSteps[p[2], vLineSteps[p[3]], vLineSteps[p[4]]];
var hLineWidths = [vLineWidths[p[0]], vLineWidths[p[1]], vLineWidths[p[2], vLineWidths[p[3]], vLineWidths[p[4]]];

function bang(){
	calcLines();
	outlet(0, "jit_matrix", copyMatrix.name);
}


function calcLines(){

	copyMatrix.frommatrix(blackMatrix);
	
	var old_dstdimstart = copyMatrix.dstdimstart;
	var old_dstdimend = copyMatrix.dstdimend;
	copyMatrix.usedstdim = 1;
	
	for(var i = 0; i < numVertLines; i++){
		var start = vLinePos[i];
		var end = vLinePos[i] + vWidths[i];
		if(start < 0 && end > 0){
			copyMatrix.dstdimstart = [0, 0];
			copyMatrix.dstdimend = [end, yDim];
			copyMatrix.frommatrix(whiteMatrix);
			copyMatrix.dstdimstart = [xDim-Math.abs(start), 0];
			copyMatrix.dstdimend = [xDim, yDim];
			copyMatrix.frommatrix(whiteMatrix);
		}
		if(start > 0 && end < xDim){
			copyMatrix.dstdimstart = [newStart, 0];
			copyMatrix.dstdimend = [newEnd, yDim];
		}
		if(start > 0 && start < xDim && end > xDim){
			copyMatrix.dstdimstart = [start, 0];
			copyMatrix.dstdimend = [xDim, yDim];
			copyMatrix.frommatrix(whiteMatrix);
			copyMatrix.dstdimstart = [0, 0];
			copyMatrix.dstdimend = [end%xDim, yDim];
		}
		
		var newStart = vLinePos[i] + vLineSteps[i];
		var newEnd = vLinePos[i] + vWidths[i] + vLineSteps[i];
		vLinePos[i] += vLineSteps[i];
		if(newStart > xDim || newEnd < 0) {
			vLinePos[i] %= xDim;
		}
	}
	
	for(var i = 0; i < numHorLines; i++){
		var start = hLinePos[i];
		var end = hLinePos[i] + hWidths[i];
		if(start < 0 && end > 0){
			copyMatrix.dstdimstart = [0, 0];
			copyMatrix.dstdimend = [xDim, end];
			copyMatrix.frommatrix(whiteMatrix);
			copyMatrix.dstdimstart = [0, yDim-Math.abs(start)];
			copyMatrix.dstdimend = [xDim, yDim];
			copyMatrix.frommatrix(whiteMatrix);
		}
		if(start > 0 && end < xDim){
			copyMatrix.dstdimstart = [0, newStart];
			copyMatrix.dstdimend = [xDim, newEnd];
		}
		if(start > 0 && start < xDim && end > xDim){
			copyMatrix.dstdimstart = [0, start];
			copyMatrix.dstdimend = [xDim, yDim];
			copyMatrix.frommatrix(whiteMatrix);
			copyMatrix.dstdimstart = [0, 0];
			copyMatrix.dstdimend = [xDim, end%yDim];
		}
		
		var newStart = vLinePos[i] + vLineSteps[i];
		var newEnd = vLinePos[i] + vWidths[i] + vLineSteps[i];
		vLinePos[i] += vLineSteps[i];
		if(newStart > xDim || newEnd < 0) {
			vLinePos[i] %= xDim;
		}
	}
	
	copyMatrix.dstdimstart = old_dstdimstart;
	copyMatrix.dstdimend = old_dstdimend;
	copyMatrix.usedstdim = 0;
}

