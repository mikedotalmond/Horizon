package util;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 * https://github.com/away3d/away3dlite-core-haxe/blob/master/src/away3dlite/haxeutils/MathUtils.hx
 */

@:final class MathUtil {
	
	public static inline var E			:Float = 2.718281828459045;
	public static inline var EE			:Float = E * E;
	public static inline var LN2		:Float = 0.6931471805599453;
	public static inline var LN10		:Float = 2.302585092994046;
	public static inline var LOG2E		:Float = 1.4426950408889634;
	public static inline var LOG10E		:Float = 0.4342944819032518;
	public static inline var SQRT2		:Float = 1.4142135623730951;
	public static inline var SQRT1_2	:Float = 0.7071067811865476;
	
	public static inline var PI			:Float = 3.141592653589793;
	public static inline var QUARTER_PI	:Float = PI / 4 ;
	public static inline var HALF_PI	:Float = PI / 2 ;
	public static inline var TWO_PI		:Float = PI * 2 ;
	public static inline var iTWO_PI	:Float = 1.0 / TWO_PI;
	
	public static inline var toRADIANS	:Float = PI / 180;
	public static inline var toDEGREES	:Float = 180 / PI;
	
	
	public static inline function abs(x:Float):Float {
		return (x < 0) ? ( -x) : x;
	}
	
	public static inline function min(x:Float, y:Float):Float {
		return (x < y) ? x : y;
	}
	
	public static inline function max(x:Float, y:Float):Float {
		return (x > y) ? x : y;
	}
	
	public static inline function absI(x:Int):Int {
		return (x < 0) ? ( -x) : x;
	}
	
	public static inline function minI(x:Int, y:Int):Int {
		return (x < y) ? x : y;
	}
	
	public static inline function maxI(x:Int, y:Int):Int {
		return (x > y) ? x : y;
	}
	
	#if js
	public static inline function rnd(seed:Int):Int return (seed * 16807) % 2147483647;
	#else
	public static inline function rnd(seed:UInt):UInt return (seed * 16807) % 2147483647;
	#end
}