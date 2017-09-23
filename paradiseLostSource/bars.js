inlets = 5;
outlets = 1;

var templateMatrix = new JitterMatrix(jsarguments[1]);
var whiteMatrix = new JitterMatrix("white");
var blackMatrix = new JitterMatrix("black");
var xDim = templateMatrix.dim[0];
var yDim = templateMatrix.dim[1]
var copyMatrix = new JitterMatrix(1, "char", xDim, yDim);

var numVertLines = jsarguments[2] ? jsarguments[2] : 0;
var numHorLines = jsarguments[3] ? jsarguments[3] : 0;

var vLinePos =   [110, 650, 280, 780, 910];
var vLineSteps = [-5, 30, 100, -20, 70];
var vLineWidths = [100, 15, 20, 70, 30];
var p = [0, 4, 2, 3, 1];
var hLinePos = [vLinePos[p[0]], vLinePos[p[1]], vLinePos[p[2]], vLinePos[p[3]], vLinePos[p[4]]];
var hLineSteps = [vLineSteps[p[0]], vLineSteps[p[1]], vLineSteps[p[2]], vLineSteps[p[3]], vLineSteps[p[4]]];
var hLineWidths = [vLineWidths[p[0]], vLineWidths[p[1]], vLineWidths[p[2]], vLineWidths[p[3]], vLineWidths[p[4]]];

var calculationOccuring = false;

function bang(){
	if(!calculationOccuring) {
		calculationOccuring = true;
		
		linesCalculated = false;
	}
	calcLines();
	post("POST LINES");
	post();
	outlet(0, "jit_matrix", copyMatrix.name);
}


function calcLines(){

	post("DRAWING LINES");
	post();
	copyMatrix.frommatrix(blackMatrix);
	
	var old_dstdimstart = copyMatrix.dstdimstart;
	var old_dstdimend = copyMatrix.dstdimend;
	copyMatrix.usedstdim = 1;
	
	//post("printing vert lines");
	//post();
	for(var i = 0; i < numVertLines; i++){
		var start = vLinePos[i];
		var end = vLinePos[i] + vLineWidths[i];
		//post("vert line " + i + " start: " + start + " end: " + end );
		//post();
		if(start <= 0 && end >= 0){
			copyMatrix.dstdimstart = [0, 0];
			copyMatrix.dstdimend = [end, yDim];
			copyMatrix.frommatrix(whiteMatrix);
			copyMatrix.dstdimstart = [xDim-Math.abs(start), 0];
			copyMatrix.dstdimend = [xDim, yDim];
			copyMatrix.frommatrix(whiteMatrix);
		}
		if(start > 0 && end < xDim){
			copyMatrix.dstdimstart = [start, 0];
			copyMatrix.dstdimend = [end, yDim];
			copyMatrix.frommatrix(whiteMatrix);
		}
		if(start > 0 && start < xDim && end > xDim){
			copyMatrix.dstdimstart = [start, 0];
			copyMatrix.dstdimend = [xDim, yDim];
			copyMatrix.frommatrix(whiteMatrix);
			copyMatrix.dstdimstart = [0, 0];
			copyMatrix.dstdimend = [end%xDim, yDim];
			copyMatrix.frommatrix(whiteMatrix);
			//post(end%xDim);
			//post();
		}
		
		var newStart = vLinePos[i] + vLineSteps[i];
		var newEnd = vLinePos[i] + vLineWidths[i] + vLineSteps[i];
		vLinePos[i] += vLineSteps[i];
		if(newStart > xDim || newEnd < 0) {
			vLinePos[i] %= xDim;
		}
		if(newEnd < 0){
			vLinePos[i] += xDim;
		}
	}
	
	//post("printing hor lines");
	//post();
	for(var i = 0; i < numHorLines; i++){
		var start = hLinePos[i];
		var end = hLinePos[i] + hLineWidths[i];
		//post("hor line " + i + " start: " + start + " end: " + end );
		//post();
		if(start <= 0 && end >= 0){
			copyMatrix.dstdimstart = [0, 0];
			copyMatrix.dstdimend = [xDim, end];
			copyMatrix.frommatrix(whiteMatrix);
			copyMatrix.dstdimstart = [0, yDim-Math.abs(start)];
			copyMatrix.dstdimend = [xDim, yDim];
			copyMatrix.frommatrix(whiteMatrix);
		}
		if(start > 0 && end < xDim){
			copyMatrix.dstdimstart = [0, start];
			copyMatrix.dstdimend = [xDim, end];
			copyMatrix.frommatrix(whiteMatrix);
		}
		if(start > 0 && start < xDim && end > xDim){
			copyMatrix.dstdimstart = [0, start];
			copyMatrix.dstdimend = [xDim, yDim];
			copyMatrix.frommatrix(whiteMatrix);
			copyMatrix.dstdimstart = [0, 0];
			copyMatrix.dstdimend = [xDim, end%yDim];
			copyMatrix.frommatrix(whiteMatrix);
		}
		
		var newStart = hLinePos[i] + hLineSteps[i];
		var newEnd = hLinePos[i] + hLineWidths[i] + hLineSteps[i];
		hLinePos[i] += hLineSteps[i];
		if(newStart > yDim) {
			hLinePos[i] %= yDim;
		}
		if(newEnd < 0){
			hLinePos[i] += yDim; 
		}
	}
	
	copyMatrix.dstdimstart = old_dstdimstart;
	copyMatrix.dstdimend = old_dstdimend;
	copyMatrix.usedstdim = 0;
}

