package worker;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

#if js
typedef FloatArray = js.html.Float32Array; // JS target performs much better using Float32Array, and, handily, Tilesheet::draw accepts the Float32Array on JS
#else
typedef FloatArray = Array<Float>;
#end

@:final class Data {
	public static inline var TYPE_INIT	:Int = 0;
	public static inline var TYPE_UPDATE:Int = 1;
}

typedef WorkerData = {
	var type:Int;
}