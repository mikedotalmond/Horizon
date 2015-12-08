package;

import flock.FlockSprites;
import js.Browser;
import js.html.Event;
import js.html.Float32Array;
import net.rezmason.utils.workers.Golem;
import net.rezmason.utils.workers.QuickBoss;
import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import pixi.filters.blur.BlurFilter;
import pixi.filters.HorizonStripShader;
import pixi.plugins.app.Application;
import worker.FlockData.FlockBoss;


/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

typedef TestThread = QuickBoss<Int, Int>;

class Main extends Application {

	//
	var container:Container;
	var shader:pixi.filters.HorizonStripShader;
	var bg2:Sprite;
	var targetStrips:Float32Array;
	var currentStrips:Float32Array;
	
	var newSliceTimer:Float = 0;
	var fSprites:FlockSprites;
	var bg:Sprite;

	static inline var NewSliceTime = 6000; // millis
	static inline var SliceCount = 7; // vertical slice count (max of 7)
	
	public function new() {
		super();
		
		antialias = false;
		backgroundColor =0;
		start(Application.WEBGL, Browser.document.getElementById('pixi-container'));
		renderer.resize(1280, 720);
		
		setup();
		
		onUpdate = draw;
		onWindowResize(null);
	}
	
	
	function setup() {
		
		currentStrips = new Float32Array([0, .1, .2, .3, .4, .5, .6]);
		targetStrips = new Float32Array(7);
		pickNewStripTargets();
		
		// setup pixi
		container = new Container();
		stage.addChild(container);
		//renderer.backgroundColor = 0x10101F;
		var t1 = Texture.fromImage("img/horizon-bg1.jpg");
		var t2 = Texture.fromImage("img/horizon-bg2.jpg");
		
		bg = new Sprite(t1);
		stage.addChild(bg);
		shader = new HorizonStripShader(t1, t2);
		bg.filters = [shader];
		
		fSprites = new FlockSprites();
		stage.addChild(fSprites);
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
	
	
	function draw(dt:Float) {
		
		var nowSeconds = now / 1000;
		
		fSprites.update(nowSeconds, dt / 1000);
		
		shader.reseed(Math.random() * 10000, Math.random() * 10000);
		
		newSliceTimer += dt;
		if(newSliceTimer >= NewSliceTime){
			newSliceTimer = 0;
			pickNewStripTargets();
		}

		// update shader parameters  
		var a = Math.sin(.5 + nowSeconds / 10.5);
		var b = Math.sin(nowSeconds / 6.666 + Math.cos(nowSeconds / 7.777));
		var c = Math.sin(.5 + nowSeconds / 10);
		// TODO: fix these values... ranges are not right 
		//shader.setYOffsetData(3*c, .5 + b*.2, 8*a);
	
		
		shader.fadePosition = (Math.sin(now / 30000) + 1) * .5;
		
		updateStrips();
	}
	
	
	function updateStrips() {
		
		// lerp slices toward targets...
		var c;
		var f=0.0002; // speed
		for (i in 0...SliceCount) {
			c = currentStrips[i];
			currentStrips[i] = c + (targetStrips[i]-c) * f;    
		}
		
		shader.setStrips(currentStrips);
	}
	
	function pickNewStripTargets() {
		var stripWidth = 1.0 / SliceCount;
		for (i in 0...SliceCount) {
			targetStrips[i] = (i * stripWidth) + Math.random() * stripWidth;  
		}
	}
	
	static function main() new Main();
}