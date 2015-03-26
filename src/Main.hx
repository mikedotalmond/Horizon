package ;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

import haxe.Timer;

import motion.Actuate;
import motion.easing.Quad.QuadEaseIn;
import motion.easing.Quad.QuadEaseOut;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.Lib;
import openfl.ui.Keyboard;

import flock.FlockTiles;
import ui.BackgroundImage;
import ui.buttons.SoundToggle;
#if (html5 || windows)
import ui.buttons.FullscreenToggle;
#end
import util.Env;
import util.MathUtil;


class Main extends Sprite {
	
	var inited			:Bool;
	
	var bgLogo			:Bitmap;
	
	var soundToggle		:SoundToggle;
	
	#if (html5||windows)
	var fullscreenToggle:FullscreenToggle;
	#end
	
	public var flock		(default, null):FlockTiles;
	public var background	(default, null):BackgroundImage;

	public var inputs		(default, null):Inputs;
	public var soundControl	(default, null):SoundControl;
	
	function init() {
		if (inited) return;
		inited = true;
		
		setupInputs();
		
		Env.setup(inputs);
		
		#if !html5
		setStageSize(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);
			#if windows
			Env.stageResized.connect(setStageSize);
			#end
		#end
		
		setupUI();	
		
		#if debugDraw
		drawDebugGrid();
		#end
		
		// fade the bg in, then setup...
		Actuate.tween(bgLogo, 1, { alpha:1 })
			.ease(new QuadEaseIn())
			.onComplete(background.setup);
			
		trace("TODO: reduce/remove runtime allocations");
		// i see some alloc/dealloc in:
		// - soundcontrol / playback  (array create,push,pop,splice)
		// - flockingworker space partitioning (array create, push)
	}
	
	
	function setStageSize(w, h):Void {
		
		var w1 = w / 1280;
		var h1 = h / 720;
		var s;
		
		#if windows
		s = MathUtil.min(w1, h1);
		#else
		s = MathUtil.max(w1, h1);
		#end
		
		x = (w / 2) - (s * 1280) / 2;
		y = (h / 2) - (s * 720) / 2;
		
		scaleX = scaleY = s;
	}
	
	
	function setupInputs():Void {		
		inputs = new Inputs();
		inputs.keyDown.connect(function(code) {
			switch(cast code) {
				case Keyboard.F:
					Env.toggleFullscreen();
				#if debugDraw
				case Keyboard.D:
					flock.debugVisible = !flock.debugVisible;
				#end
			}
		});
		
		inputs.doubleClick.connect(function(_,_) {
			Env.toggleFullscreen();
		});
	}
	
	
	function setupUI():Void {
		
		background = new BackgroundImage(this);	
		background.ready.connect(backgroundImageDataReady, Once);		
		
		addChild(bgLogo = new Bitmap(Assets.getBitmapData('img/horizon.png'), null, true));
		bgLogo.alpha = 0;
		
		soundToggle = new SoundToggle(inputs);
		soundToggle.toggle.connect(function(soundOn) soundControl.setPause(!soundOn));
		
		#if (html5 || windows)
		fullscreenToggle = new FullscreenToggle(inputs);
		#end
	}
	
	
	function backgroundImageDataReady() {
		Actuate.tween(bgLogo, 1, { alpha:0 } )
			.delay(.5)
			.ease(new QuadEaseOut())
			.onComplete(start);
	}
	
	
	function start(){
		
		removeChild(bgLogo);
		bgLogo.bitmapData.dispose();
		bgLogo.bitmapData = null;
		bgLogo = null;
		
		addChild(flock = new FlockTiles(inputs));
		soundControl = new SoundControl(inputs, flock);
		soundControl.play(0, 0, 0, 0); // start sound
		
		#if html5
		js.Browser.document.addEventListener("visibilitychange", onVisibilityChange);
		#elseif cpp
		stage.addEventListener(Event.ACTIVATE, stateHandler);
		stage.addEventListener(Event.DEACTIVATE, stateHandler);
		#end
		
		soundToggle.setup(this, 10, 10);
		
		#if (html5||windows)
		fullscreenToggle.setup(this, 1210, 6);
		#end
		
		background.update();
	}
	
	#if html5
	function onVisibilityChange(_) { 
		soundToggle.toggle.emit(js.Browser.document.visibilityState != 'hidden');
	}
	#elseif cpp
	function stateHandler(e:Event) {
		soundToggle.toggle.emit(e.type == Event.ACTIVATE);
	}
	#end
	
	#if (debugDraw)
	function drawDebugGrid():Void {
		var shp = new Shape();
		shp.graphics.lineStyle(1, 0xff0000, 1);
		for (x in 0...4) {
			shp.graphics.moveTo(x*(1280/4), 0);
			shp.graphics.lineTo(x*(1280/4), 720);
		}
		for (y in 0...4) {
			shp.graphics.moveTo(0, y*(720/4));
			shp.graphics.lineTo(1280, y*(720/4));
		}
		addChild(shp);
	}
	#end
	
	/* -----------------------------------------------------------------*/
	/* -----------------------------------------------------------------*/
	
	/* setup */
	public function new() {
		super();			
		addEventListener(Event.ADDED_TO_STAGE, added);
	}

	function added(e) {
		removeEventListener(Event.ADDED_TO_STAGE, added);
		stage.addEventListener(Event.RESIZE, resize);
		#if ios
		haxe.Timer.delay(init, 100); // iOS 6
		#else
		init();
		#end
	}
	
	function resize(e) {
		if (!inited) init();
	}
	
	public static function main() {
		// entry point
		Lib.current.stage.align = flash.display.StageAlign.TOP_LEFT;
		Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
		Lib.current.addChild(new Main());
	}
}

