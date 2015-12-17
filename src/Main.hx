package;

import flock.FlockSprites;
import js.Browser;
import js.html.Element;
import js.html.Event;
import js.html.Float32Array;
import js.html.KeyboardEvent;
import motion.actuators.SimpleActuator;
import motion.easing.Sine;
import net.rezmason.utils.workers.QuickBoss;
import pixi.core.graphics.Graphics;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import pixi.filters.blur.BlurFilter;
import pixi.filters.HorizonStripShader;
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
	
	var newSliceTimer:Float = 0;
	var flock:FlockSprites;

	var seconds:Float = 0;
	var container:Element;
	var textures:Array<Texture>;	
	var bgTextureIndex:Int = 1;
	var fadePhase:Float = 0;
	
	var audio:SeascapeAudio;
	
	
	public function new() {
		
		super();
		
		container = Browser.document.getElementById('pixi-container');
		
		antialias = false;
		backgroundColor =0;
		start(Application.WEBGL, container);
		renderer.resize(1280, 720);
		
		SimpleActuator.getTime = function () return seconds;
		
		inputs = new util.Inputs(stage);
		inputs.hidePointerWhenIdle = true;
		
		currentStrips = new Float32Array([0, .15, .3, .45, .6, .75, .9]);
		targetStrips = new Float32Array(7);
		pickNewStripTargets();
		
		setupPixi();
		setupAudio();
		
		onUpdate = update;
		onWindowResize(null);
		
		if (Screenfull != null && Screenfull.enabled) {
			inputs.keyDown.connect(function(code:Int) {
				if (code == KeyboardEvent.DOM_VK_ESCAPE) Screenfull.exit();
				else if(code == KeyboardEvent.DOM_VK_F) Screenfull.toggle(container);
			});
			Browser.document.addEventListener(Screenfull.raw.fullscreenchange, onWindowResize.bind(null));
		}
	}
	
	
	function setupAudio() {
		
		audio = new SeascapeAudio();
		
		audio.error.connect(function(err) {
			trace(err);
		});
		audio.loadProgress.connect(function(value) {
			trace('loadProgress:$value');
		});
		audio.bufferLoaded.connect(function() {
			trace('bufferLoaded');
			audio.decodeBuffer();
		});
		audio.ready.connect(function() {
			trace('ready');
			
			audio.playRegion(0, 0.25, .5, 5, 1);
			//audio.playRegion(Std.int(Math.random() * SeascapeAudio.regions.length), 0.25, 0, 0, 1);
		});
		
		audio.loadBuffer();
	}
	
	
	function setupPixi() {
		
		var t1 = Texture.fromImage("img/horizon-bg1.jpg");
		var t2 = Texture.fromImage("img/horizon-bg2.jpg");
		var t3 = Texture.fromImage("img/horizon-bg3.jpg");
		var t4 = Texture.fromImage("img/horizon-bg4.jpg");
		
		textures = [t1,t2,t3,t4];
		
		var bg = new Sprite(t1);
		bg.interactive = true;
		stage.addChild(bg);
		
		shader = new HorizonStripShader(t1, t2);
		shader.setStrips(currentStrips);
		
		var blur = new BlurFilter();
		blur.blur = .5;
		
		bg.filters = [shader, blur];
		
		flock = new FlockSprites(inputs);
		stage.addChild(flock);
		
		#if debugDraw
		debugGraphics = new Graphics();
		stage.addChild(debugGraphics);
		#end
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
		
		SimpleActuator.stage_onEnterFrame();
		
		inputs.update(elapsed);
		
		var newFlockData = flock.update(seconds, dt);
		//if (newFlockData) soundControl.update(dt, flock.drawList, FlockSprites.DataSize);
		
		updateShaderParameters(seconds, dt);
		
		updateSlices(dt);
	}
	
	
	function pickNewStripTargets() {
		var stripWidth = 1.0 / SliceCount;
		for (i in 0...SliceCount) targetStrips[i] = (i * stripWidth) + (Math.random() * stripWidth);
	}
	
	
	inline function updateShaderParameters(t:Float, dt:Float) {
		
		shader.reseed(Math.random() * 10000, Math.random() * 10000);
		
		var a = .5 * Math.sin(.5 + t / 10.5);
		var b = Math.sin(t / 6.666 + Math.cos(t / 7.777));
		var c = .005 * Math.sin(.5 + t / 10);
		shader.setYOffsetData(c, .5 + b*.2, a);
		
		fadePhase += (dt / 60);
		if (fadePhase >= 1) {
			
			fadePhase = 0;
			shader.fadePosition = 0;
			
			var lastIndex = bgTextureIndex;
			
			bgTextureIndex++;
			if (bgTextureIndex == textures.length) bgTextureIndex = 0;
			
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