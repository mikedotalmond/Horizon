package;

import flock.FlockSprites;
import hxsignal.Signal.ConnectionTimes;
import js.Browser;
import js.html.Element;
import js.html.Event;
import js.html.Float32Array;
import js.html.KeyboardEvent;
import js.html.VisibilityState;
import motion.Actuate;
import motion.actuators.SimpleActuator;
import motion.easing.Quad;
import motion.easing.Sine;
import net.rezmason.utils.workers.QuickBoss;
import pixi.core.graphics.Graphics;
import pixi.core.Pixi;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import pixi.filters.blur.BlurFilter;
import pixi.filters.HorizonStripShader;
import pixi.loaders.Loader;
import pixi.plugins.app.Application;
import sound.SeascapeAudio;
import util.Inputs;
import util.Screenfull;


/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

typedef TestThread = QuickBoss<Int, Int>;

class Main extends Application {

	static inline var NewSliceTime = 3; // seconds
	static inline var SliceCount = 7; // vertical slice count (max of 7)
	
	//
	var lastTime:Float = 0;
	var shader:HorizonStripShader;
	var targetStrips:Float32Array;
	var currentStrips:Float32Array;
	
	var inputs:Inputs;
	var fullscreenEnabled:Bool;
	
	var newSliceTimer:Float = 0;
	var flock:FlockSprites;

	var seconds:Float = 0;
	var container:Element;
	var textures:Array<Texture>;	
	var bgTextureIndex:Int = 1;
	var fadePhase:Float = 0;
	
	var audio:SeascapeAudio;
	
	var ready:Bool;
	var paused:Bool;
	var mutedBeforePause:Bool;
	var loader:AssetLoader;
	
	public function new() {
		ready = false;
		
		super();
		
		setupPixi();
		
		SimpleActuator.getTime = function () return seconds;
		
		inputs = new Inputs(stage);
		inputs.hidePointerWhenIdle = true;
		
		currentStrips = new Float32Array([0, .15, .3, .45, .6, .75, .9]);
		targetStrips = new Float32Array(7);
		pickNewStripTargets();
		
		audio = new SeascapeAudio();
		
		loader = new AssetLoader(stage, audio);
		loader.complete.connect(onAssetsReady, ConnectionTimes.Once);
		
		onUpdate = update;
		onWindowResize(null);
		
		inputs.keyDown.connect(onKeyDown);
		
		fullscreenEnabled = (Screenfull != null && Screenfull.enabled);
		if (fullscreenEnabled) Browser.document.addEventListener(Screenfull.raw.fullscreenchange, onWindowResize.bind(null));
		
		// pause and mute audio when tab looses focus - revert when active
		Browser.document.addEventListener('visibilitychange', onVisibilityChange);
	}
	
	
	function onVisibilityChange(_) {
		if (Browser.document.visibilityState == VisibilityState.HIDDEN) {
			mutedBeforePause = audio.muted;
			if (!mutedBeforePause) audio.toggleMute();
			paused = true;
		} else {
			paused = false;
			if (audio.muted && !mutedBeforePause) audio.toggleMute();
			
		}
	}
	
	
	function onKeyDown(code:Int) {
		switch(code) {
			case KeyboardEvent.DOM_VK_ESCAPE: 
				if (fullscreenEnabled) Screenfull.exit();
				
			case KeyboardEvent.DOM_VK_F: 
				if (fullscreenEnabled) Screenfull.toggle(container);
				
			case KeyboardEvent.DOM_VK_M:
				audio.toggleMute();
		}
	}
	
	
	function onAssetsReady() {
		audio.start();
		
		textures = loader.textures;
		
		var display = new Sprite(textures[0]);
		display.interactive = true;
		stage.addChildAt(display, 0);
		
		shader = new HorizonStripShader(textures[0], textures[1]);
		shader.setStrips(currentStrips);
		
		var blur = new BlurFilter();
		blur.blur = .5;
		
		display.filters = [shader, blur];
		
		flock = new FlockSprites(inputs);
		stage.addChild(flock);
		
		#if debugDraw
		debugGraphics = new Graphics();
		stage.addChild(debugGraphics);
		#end
		
		ready = true; 
	}
	
	
	function setupPixi() {
		container = Browser.document.getElementById('pixi-container');
		antialias = false;
		backgroundColor =0;
		start(Application.WEBGL, container);
		renderer.resize(1280, 720);
	}
	
	
	
	override function onWindowResize(event:Event) {
		
		var fullW = Browser.window.innerWidth;
		var fullH = Browser.window.innerHeight;
		
		var r1 = fullW / 1280;
		var r2 = fullH / 720;
		
		if (r1 < r2) {
			width = fullW;
			height = 720 * r1;
		} else {
			height = fullH;
			width = 1280 * r2;
		}
		
		canvas.style.top = (fullH/2 - height/2) + "px";
		canvas.style.left = (fullW/2 - width/2) + "px";
		canvas.style.width = width + "px";
		canvas.style.height = height + "px";
	}
	
	
	function update(elapsed:Float) {
		
		seconds = elapsed / 1000;
		var dt = (seconds - lastTime);
		lastTime = seconds;
		
		if (ready && paused) return;
		
		SimpleActuator.stage_onEnterFrame();
		
		if (!ready) return;
		
		inputs.update(elapsed);
		flock.update(seconds, dt);
		
		updateShaderParameters(seconds, dt);
		updateSlices(dt);
	}
	
	
	function pickNewStripTargets() {
		var stripWidth = 1.0 / SliceCount;
		for (i in 0...SliceCount) targetStrips[i] = (i * stripWidth) + (Math.random() * stripWidth);
	}
	
	var fadeRate:Float = 8;
	inline function updateShaderParameters(t:Float, dt:Float) {
		
		shader.reseed(Math.random() * 10000, Math.random() * 10000);
		
		var a = .5 * Math.sin(.5 + t / 10.5);
		var b = Math.sin(t / 6.666 + Math.cos(t / 7.777));
		var c = .005 * Math.sin(.5 + t / 10);
		shader.setYOffsetData(c, .5 + b*.2, a);
		
		fadePhase += (dt / fadeRate);
		if (fadePhase >= 1) {
			
			var minFadeRate = 10;
			var maxFadeRate = 60;
			fadeRate = minFadeRate +  Math.random() * (maxFadeRate-minFadeRate);
			
			fadePhase = 0;
			shader.fadePosition = 0;
			
			var lastIndex = bgTextureIndex;
			// pick new random index - not the same as last one
			while (bgTextureIndex == lastIndex) {
				bgTextureIndex = (bgTextureIndex + Std.int(Math.random()*textures.length)) % textures.length;
			}
			
			shader.textureA = textures[lastIndex];
			shader.textureB = textures[bgTextureIndex];
			
		} else {
			shader.fadePosition = Sine.easeInOut.calculate(fadePhase);
		}
	}
	
	
	inline function updateSlices(dt) {
		
		newSliceTimer += dt;
		if(newSliceTimer >= NewSliceTime){
			newSliceTimer = 0;
			pickNewStripTargets();
		}
		
		// lerp slices toward targets...
		var c;
		var f = 0.0015; // speed
		for (i in 0...SliceCount) {
			c = currentStrips[i];
			currentStrips[i] = c + (targetStrips[i]-c) * f;    
		}
		
		shader.setStrips(currentStrips);
		
		#if debugDraw
		debugDraw();
		#end
	}
	
	
	#if debugDraw 
	var debugGraphics:Graphics;
	function debugDraw() {
		debugGraphics.clear();
		debugGraphics.alpha = .2;
		for (i in 0...SliceCount) {
			debugGraphics.lineStyle(2,0);
			debugGraphics.moveTo(currentStrips[i]*1280,0);
			debugGraphics.lineTo(currentStrips[i]*1280,720);
			debugGraphics.lineStyle(2,0xff0000);
			debugGraphics.moveTo(targetStrips[i]*1280,0);
			debugGraphics.lineTo(targetStrips[i]*1280,720);
		}
	}
	#end
	
	
	
	//
	static function main() new Main();
}