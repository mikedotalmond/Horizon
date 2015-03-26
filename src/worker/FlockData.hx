package worker;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

import net.rezmason.utils.workers.QuickBoss;

import worker.Data.FloatArray;
import worker.Data.WorkerData;

@:final class FlockData { 
	public static inline var X_DATA_POINTS:Int = 48; // vx
	public static inline var Y_DATA_POINTS:Int = 48; // vy
	public static inline var TILE_FIELDS:Int = 5; // x, y, index, alpha, scale
}

@:final typedef FlockBoss = QuickBoss<WorkerData, FloatArray>;

@:final typedef FlockInitData = {> WorkerData,
	var screenDensity:Float;
	var count:Int;
}

@:final typedef FlockUpdateData = {> WorkerData,
	var pointForces:FloatArray; /* [pX, pY, f, ... ] */
	var scaleFactor:Float;
}
