package;

import flock.FlockSprites;
import js.html.Element;
import js.html.KeyboardEvent;
import util.Screenfull;
//import flock.SoundControl;
import js.Browser;
import js.html.Event;
import js.html.Float32Array;
import motion.actuators.SimpleActuator;
import net.rezmason.utils.workers.QuickBoss;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import pixi.filters.blur.BlurFilter;
import pixi.filters.HorizonStripShader;
import pixi.plugins.app.Application;
import util.Inputs;


/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

typedef TestThread = QuickBoss<Int, Int>;

class Main extends Application {

	//
	var lastTime:Float = 0;
	var shader:HorizonStripShader;
	var targetStrips:Float32Array;
	var currentStrips:Float32Array;
	
	var inputs:util.Inputs;
	
	var newSliceTimer:Float = 0;
	var flock:FlockSprites;

	static inline var NewSliceTime = 6; // seconds
	static inline var SliceCount = 7; // vertical slice count (max of 7)
	//var soundControl:flock.SoundControl;
	
	var seconds:Float = 0;
	var container:Element;
	
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
		
		//soundControl = new SoundControl(flock);
		
		currentStrips = new Float32Array([0, .15, .3, .45, .6, .75, .9]);
		targetStrips = new Float32Array(7);
		pickNewStripTargets();
		
		setupPixi();
		
		onUpdate = update;
		onWindowResize(null);
		
		if (Screenfull != null && Screenfull.enabled) {
			
			inputs.keyDown.connect(function(code:Int) {
				if (code == KeyboardEvent.DOM_VK_ESCAPE) Screenfull.exit();
				else if(code == KeyboardEvent.DOM_VK_F) Screenfull.toggle(container);
			});
			
			Browser.document.addEventListener(Screenfull.raw.fullscreenchange, function (_) {
				trace('fullscreenchange - isFullscreen:${Screenfull.isFullscreen}');
				onWindowResize(null);
			});
		}
	}
	
	
	function setupPixi() {
		
		var t1 = Texture.fromImage("img/horizon-bg1.jpg");
		var t2 = Texture.fromImage("img/horizon-bg2.jpg");
		var t3 = Texture.fromImage("img/horizon-bg3.jpg");
		var t4 = Texture.fromImage("img/horizon-bg4.jpg");
		
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
		
		updateShaderParameters(seconds);
		
		updateSlices(dt);
	}
	
	
	inline function updateShaderParameters(t:Float) {
		
		shader.reseed(Math.random() * 10000, Math.random() * 10000);
		
		var a = .5 * Math.sin(.5 + t / 10.5);
		var b = Math.sin(t / 6.666 + Math.cos(t / 7.777));
		var c = .005 * Math.sin(.5 + t / 10);
		shader.setYOffsetData(c, .5 + b*.2, a);
		
		var p = (Math.sin(t / 30) + 1) * .5;
		shader.fadePosition = p;
	}
	
	
	inline function updateSlices(dt) {
		
		newSliceTimer += dt;
		if(newSliceTimer >= NewSliceTime){
			newSliceTimer = 0;
			pickNewStripTargets();
		}
		
		// lerp slices toward targets...
		var c;
		var f=0.0008; // speed
		for (i in 0...SliceCount) {
			c = currentStrips[i];
			currentStrips[i] = c + (targetStrips[i]-c) * f;    
		}
		
		shader.setStrips(currentStrips);
	}
	
	
	function pickNewStripTargets() {
		var stripWidth = 1.0 / SliceCount;
		for (i in 0...SliceCount) targetStrips[i] = (i * stripWidth) + Math.random() * stripWidth;
	}
	
	
	//
	
	
	static function main() new Main();
}