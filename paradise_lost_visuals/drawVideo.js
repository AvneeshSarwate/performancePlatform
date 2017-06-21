var selector = new JitterMatrix("selector");
var xDim = selector.dim[0];
var yDim = selector.dim[1];
var copyMatrix = new JitterMatrix(4, "char", xDim, yDim);
copyMatrix.usedstdim = 1;
var ro_matrixInd = 0;
var ro_dimstart = [0,0];
var ro_dimend = [xDim, yDim];
var radius = 40;
var vidInd = 1;

function dist(x1, y1, x2, y2) {
	return Math.sqrt(Math.pow(x1-x2, 2) + Math.pow(y1-y2, 2));
}

//x, y
function drawcircle(){
	var x = Math.round(arguments[0] * (xDim-1));
	var y = Math.round(arguments[1] * (yDim-1));
	var xMax = Math.min(xDim-1, x+radius);
	var yMax = Math.min(yDim-1, y+radius);
	var xMin = Math.max(0, x-radius);
	var yMin = Math.max(0, y-radius)
	post(x, y, xMin, yMin, xMax, yMax, (xMax-xMin)*(yMax-yMin));
	post();
	for(var i = xMin; i < xMax; i++) {
		for(var j = yMin; j < yMax; j++ ) {
			//post(i, j);
			//post();
			if(dist(i,j,x,y) < radius) selector.setcell2d(i, j, vidInd);
		}
	}
}
