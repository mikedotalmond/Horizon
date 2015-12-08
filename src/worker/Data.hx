package worker;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

@:final class Data {
	public static inline var TYPE_INIT	:Int = 0;
	public static inline var TYPE_UPDATE:Int = 1;
}

typedef WorkerData = {
	var type:Int;
}