package util;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

import haxe.Timer;
import hxsignal.Signal;
import openfl.display.StageDisplayState;
import openfl.events.KeyboardEvent;
import openfl.Lib;
import openfl.events.Event;
import openfl.system.Capabilities;
import openfl.ui.Keyboard;

@:final class Env {
		
	public static var width(default, null):Int;
	public static var height(default, null):Int;
	public static var scaleFactor(default, null):Float;
	public static var screenDensity(default, null):Float;

	public static var fullscreenChange(default, null):Signal<Bool->Void>;
	public static var stageResized(default, null):Signal<Int->Int->Void>;
	
	#if html5
	static var container:js.html.DivElement;
	static var canvas:js.html.CanvasElement;
	#end
	
	public static function setup (inputs:Inputs):Void {
		
		var dpi = Capabilities.screenDPI;
		
		if (dpi < 200) {
			screenDensity = 1;
		} else if (dpi < 300) {
			screenDensity = 1.5;
		} else {
			screenDensity = 2;
		}
		
		Lib.current.stage.addEventListener(Event.RESIZE, stage_onResize);
		
		stageResized = new Signal<Int->Int->Void>();
		fullscreenChange = new Signal<Bool->Void>();
		
		scaleFactor = 1.0;
		
		#if windows
			inputs.keyDown.connect(function(code) {
				if (code == Keyboard.ESCAPE && isFullscreen) toggleFullscreen();
			});
		#elseif html5
			var w = js.Browser.window;
			var d = js.Browser.document;
			
			container = cast d.getElementById('openfl-content');
			canvas = cast container.firstElementChild;
			
			w.addEventListener('resize', handleDomResize);
			
			var screenfull = Reflect.hasField(w, 'screenfull') ? Reflect.getProperty(w, 'screenfull') : null;
			if (screenfull != null && screenfull.enabled) {
				d.addEventListener(screenfull.raw.fullscreenchange, function (_) {
					fullscreenChange.emit(screenfull.isFullscreen);
					w.dispatchEvent(new js.html.Event('resize'));
				});
			}
			
			handleDomResize(null);
		#end
		
		stage_onResize(null);
	}
	
	
	public static function toggleFullscreen():Void {
		#if html5
			var w = js.Browser.window;
			var screenfull = Reflect.hasField(w, 'screenfull') ? Reflect.getProperty(w, 'screenfull') : null;
			if (screenfull != null && screenfull.enabled) screenfull.toggle(container);
		#elseif windows 
			if (!isFullscreen) Lib.current.stage.displayState = StageDisplayState.FULL_SCREEN;
			else Lib.current.stage.displayState = StageDisplayState.NORMAL;
			fullscreenChange.emit(isFullscreen);
		#end
	}
	
	public static var isFullscreen(get, never):Bool;
	static function get_isFullscreen() {
		
		#if html5
		var w = js.Browser.window;
		var screenfull = Reflect.hasField(w, 'screenfull') ? Reflect.getProperty(w, 'screenfull') : null;
		if (screenfull != null && screenfull.enabled) return screenfull.isFullscreen;
		#elseif windows
		return Lib.current.stage.displayState == StageDisplayState.FULL_SCREEN;
		#end
		
		return false;
	}
	
	
	#if html5
	static private function handleDomResize(e:Event):Void {
		scaleFactor = canvas.clientWidth / canvas.width;
	}
	#end	
	
	// Event Handlers
	static function stage_onResize (event:Event):Void {
		width = Math.ceil(Lib.current.stage.stageWidth / screenDensity);
		height = Math.ceil(Lib.current.stage.stageHeight / screenDensity);
		stageResized.emit(width, height);
	}
}