var m1 = new JitterMatrix("m1");
var m2 = new JitterMatrix("m2");
var m3 = new JitterMatrix("m3");
var m4 = new JitterMatrix("m4");
var xDim = m1.dim[0];
var yDim = m1.dim[1];
var copyMatrix = new JitterMatrix(4, "char", xDim, yDim);
var bangCount = 0;
var matricies = [m1, m2, m3, m4];
copyMatrix.usedstdim = 1;
var ro_matrixInd = 0;
var ro_dimstart = [0,0];
var ro_dimend = [xDim, yDim];

function bang(){
	bangCount++;
	randomGrow();
	outlet(0, "jit_matrix", copyMatrix.name);
}

function rand(num){
	return Math.floor(Math.random()*num);
}

function rand2(low, high){
	return low + Math.floor(Math.random()*(high-low));
}

function randomOverlay_ro() {
	if(bangCount % 10 == 0) {
		var ro_matrixInd = rand(4);
		copyMatrix.dstdimstart = [rand(xDim/3), rand(yDim/3)];
		ro_dimstart = [rand(xDim/3), rand(yDim/3)];
		copyMatrix.dstdimend = [rand2(2*xDim/3, xDim), rand2(2*yDim/3, yDim)];
		ro_dimend = [rand2(2*xDim/3, xDim), rand2(2*yDim/3, yDim)];
		copyMatrix.frommatrix(matricies[ro_matrixInd]);
	}
	else {
		copyMatrix.frommatrix(matricies[ro_matrixInd]);
	}
}

function randomGrow() {
	if(bangCount % 30 == 0) {
		ro_matrixInd = rand(4);
		copyMatrix.dstdimstart = [rand(xDim/3), rand(yDim/3)];
		ro_dimstart = [rand(xDim/3), rand(yDim/3)];
		copyMatrix.dstdimend = [rand2(2*xDim/3, xDim), rand2(2*yDim/3, yDim)];
		ro_dimend = [rand2(2*xDim/3, xDim), rand2(2*yDim/3, yDim)];
		copyMatrix.frommatrix(matricies[ro_matrixInd]);
	}
	else {
		ro_dimstart = [Math.max(0, ro_dimstart[0]-10), Math.max(0,ro_dimstart[1]-10)];
		ro_dimend = [Math.min(xDim, ro_dimend[0]+10), Math.min(yDim, ro_dimend[1]+10)];
		copyMatrix.usedstdim=1;
		copyMatrix.dstdimstart = ro_dimstart;
		copyMatrix.dstdimend = ro_dimend;
		//post(ro_matrixInd, copyMatrix.dstdimstart[0], copyMatrix.dstdimstart[1], copyMatrix.dstdimend[0], copyMatrix.dstdimend[1]);
		//post();
		copyMatrix.frommatrix(matricies[ro_matrixInd]);
	}
}