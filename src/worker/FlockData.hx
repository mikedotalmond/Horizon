package worker;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

import js.html.Float32Array;
import net.rezmason.utils.workers.QuickBoss;

import worker.Data.WorkerData;

@:final class FlockData { 
	
	public static inline var FIELD_COUNT:Int = 4; // x, y, alpha, scale
	public static inline var DATA_X		:Int = 0;
	public static inline var DATA_Y		:Int = 1;
	public static inline var DATA_SCALE	:Int = 2;
	public static inline var DATA_ALPHA	:Int = 3;
}

@:final typedef FlockBoss = QuickBoss<WorkerData, Float32Array>;

@:final typedef FlockInitData = {> WorkerData,
	var count:Int;
}

@:final typedef FlockUpdateData = {> WorkerData,
	var pointForces:Float32Array; /* [pX, pY, f, ... ] */
}
