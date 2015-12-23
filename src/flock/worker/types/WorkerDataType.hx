package flock.worker.types;

@:enum abstract WorkerDataType(Int) {
	var INIT = 0;
	var UPDATE = 1;
}