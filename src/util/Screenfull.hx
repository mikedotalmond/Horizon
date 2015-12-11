package util;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

import js.html.Element;

// https://github.com/sindresorhus/screenfull.js/

@:native('screenfull')
extern class Screenfull {
	
	public static var raw(default, never):Dynamic<String>;
	public static var enabled(default, never):Bool;
	public static var isFullscreen(default, never):Bool;
	public static var element(default, never):Element;
	
	public static function exit():Void;
	public static function toggle(?container:Element):Void;
	public static function request(?container:Element):Void;
}