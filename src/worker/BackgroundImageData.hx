package worker;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

import openfl.utils.Int32Array;
import worker.Data.WorkerData;
import net.rezmason.utils.workers.QuickBoss;

@:final typedef BackgroundBoss 	= QuickBoss<WorkerData, Int32Array>;

@:final class BackgroundImageData { 	

	public static inline var Width = 1280;
	public static inline var Height = 720;
	public static inline var PixelCount = Width * Height;
	public static inline var TYPE_STRIP_UPDATE = 3;
}

typedef BackgroundInitData = {> WorkerData,
	var sources:Array<Int32Array>;
}

typedef BackgroundUpdateData = {> WorkerData,
	var seed:Int;
	var index:Int;
}

typedef BackgroundStripUpdateData = {> WorkerData,
	var yIndex:Int;
	var y:Int;
}