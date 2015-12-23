package flock.worker.types;

import js.html.Float32Array;

typedef FlockUpdateData = {> WorkerData,
	var pointForces:Float32Array; /* [pX, pY, pF, ... ] */
}