package ui;

import haxe.Timer;
import motion.Actuate;
import motion.easing.Quad.QuadEaseOut;
import openfl.display.Shape;
import openfl.display.Preloader;
import openfl.display.Sprite;
import openfl.events.Event;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */
@:keep
class HorizonPreloader extends OpenFLPreloader {

	//var outline:Sprite;
	//var progress:Sprite;
	
	public function new() {
		super();
	}
	
	override public function onInit():Void {
		//NMEPreloader
		progress = new Sprite();
		progress.graphics.beginFill (0x0a0a0a, 1);
		progress.graphics.drawRect(0, 0, 1280, 720-220);
		progress.graphics.endFill();
		progress.scaleY = 0;
		addChild(progress);
		
		outline = new Sprite();
		outline.graphics.beginFill (0x0a0a0a, 1);
		outline.graphics.drawRect(0, 0, 1280, 220);
		outline.graphics.endFill();
		outline.y = 720;
		outline.scaleY = 0;
		addChild(outline);
	}
	
	//
	override public function onUpdate (loaded:Int, total:Int):Void {
		var pct = loaded / total;
		if (pct > 1) pct = 1;
		Actuate.tween(progress, .25, {scaleY : pct}).ease(new QuadEaseOut());
		Actuate.tween(outline, .25, {scaleY : -pct}).ease(new QuadEaseOut());
	}
	
	override function onLoaded() {
		trace('onLoaded');
		Timer.delay(function() {
			trace('delayed complete');
			dispatchEvent(new Event(Event.COMPLETE));
		}, 500);
	}
}