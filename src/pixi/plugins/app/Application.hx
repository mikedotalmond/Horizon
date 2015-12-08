package pixi.plugins.app;

import js.html.Element;
import pixi.core.renderers.webgl.WebGLRenderer;
import pixi.core.renderers.canvas.CanvasRenderer;
import pixi.core.renderers.SystemRenderer;
import pixi.core.renderers.Detector;
import pixi.core.display.Container;
import js.html.Event;
import js.html.CanvasElement;
import js.Browser;

import tones.utils.TimeUtil;

/**
 * Pixi Boilerplate Helper class that can be used by any application
 * @author Adi Reddy Mora
 * http://adireddy.github.io
 * @license MIT
 * @copyright 2015
 *
 * Changes from the above:
 * Use performance api in place of Date.now()
 * User TimeUtil to share a single requestanimationFrame
 * De-underscored the privates.
 */
class Application {
	
	public static inline var AUTO:String = "auto";
	public static inline var RECOMMENDED:String = "recommended";
	public static inline var CANVAS:String = "canvas";
	public static inline var WEBGL:String = "webgl";
	
	/**
	 * time since application started - window.performance.now()
	 * @return
	 */
	public static inline function now():Float return Browser.window.performance.now();
	

	/**
     * Sets the pixel ratio of the application.
     * default - 1
     */
	public var pixelRatio:Float;

	/**
	 * Default frame rate is 60 FPS and this can be set to true to get 30 FPS.
	 * default - false
	 */
	public var skipFrame(default, set):Bool;

	/**
	 * Default frame rate is 60 FPS and this can be set to anything between 1 - 60.
	 * default - 60
	 */
	public var fps(default, set):Int;

	/**
	 * Width of the application.
	 * default - Browser.window.innerWidth
	 */
	public var width:Float;

	/**
	 * Height of the application.
	 * default - Browser.window.innerHeight
	 */
	public var height:Float;

	/**
	 * Renderer transparency property.
	 * default - false
	 */
	public var transparent:Bool;

	/**
	 * Graphics antialias property.
	 * default - false
	 */
	public var antialias:Bool;

	/**
	 * Force FXAA shader antialias instead of native (faster).
	 * default - false
	 */
	public var forceFXAA:Bool;

	/**
	 * Force round pixels.
	 * default - false
	 */
	public var roundPixels:Bool;

	/**
	 * Whether you want to resize the canvas and renderer on browser resize.
	 * Should be set to false when custom width and height are used for the application.
	 * default - true
	 */
	public var autoResize:Bool;

	/**
	 * Sets the background color of the stage.
	 * default - 0xFFFFFF
	 */
	public var backgroundColor:Int;

	/**
	 * Update listener 	function
	 */
	public var onUpdate:Float -> Void;

	/**
	 * Window resize listener 	function
	 */
	public var onResize:Void -> Void;

	/**
	 * Canvas Element
	 * Read-only
	 */
	public var canvas(default, null):CanvasElement;

	/**
	 * Renderer
	 * Read-only
	 */
	public var renderer(default, null):Dynamic;

	/**
	 * Global Container.
	 * Read-only
	 */
	public var stage(default, null):Container;
	

	var lastTime:Float;
	var currentTime:Float;
	var elapsedTime:Float;
	var frameCount:Int;

	public function new() {
		lastTime = Browser.window.performance.now();
		_setDefaultValues();
	}

	function set_fps(val:Int):Int {
		frameCount = 0;
		return fps = (val >= 1 && val < 60) ? Std.int(val) : 60;
	}

	function set_skipFrame(val:Bool):Bool {
		if (val) {
			trace("pixi.plugins.app.Application > Deprecated: skipFrame - use fps property and set it to 30 instead");
			fps = 30;
		}
		return skipFrame = val;
	}

	function _setDefaultValues() {
		pixelRatio = 1;
		skipFrame = false;
		autoResize = true;
		transparent = false;
		antialias = false;
		forceFXAA = false;
		backgroundColor = 0xFFFFFF;
		width = Browser.window.innerWidth;
		height = Browser.window.innerHeight;
		fps = 60;
	}

	/**
	 * Starts pixi application setup using the properties set or default values
	 * @param [rendererType] - Renderer type to use AUTO (default) | CANVAS | WEBGL
	 * @param [stats] - Enable/disable stats for the application.
	 * Note that stats.js is not part of pixi so don't forget to include it you html page
	 * Can be found in libs folder. "libs/stats.min.js" <script type="text/javascript" src="libs/stats.min.js"></script>
	 * @param [parentDom] - By default canvas will be appended to body or it can be appended to custom element if passed
	 */

	public function start(?rendererType:String = "auto", ?parentDom:Element) {
		canvas = Browser.document.createCanvasElement();
		canvas.style.width = width + "px";
		canvas.style.height = height + "px";
		canvas.style.position = "absolute";
		if (parentDom == null) Browser.document.body.appendChild(canvas);
		else parentDom.appendChild(canvas);

		stage = new Container();

		var renderingOptions:RenderingOptions = {};
		renderingOptions.view = canvas;
		renderingOptions.backgroundColor = backgroundColor;
		renderingOptions.resolution = pixelRatio;
		renderingOptions.antialias = antialias;
		renderingOptions.forceFXAA = forceFXAA;
		renderingOptions.autoResize = autoResize;
		renderingOptions.transparent = transparent;

		if (rendererType == AUTO) renderer = Detector.autoDetectRenderer(width, height, renderingOptions);
		else if (rendererType == CANVAS) renderer = new CanvasRenderer(width, height, renderingOptions);
		else renderer = new WebGLRenderer(width, height, renderingOptions);

		if (roundPixels) renderer.roundPixels = true;
		if (autoResize) Browser.window.onresize = _onWindowResize;
		
		TimeUtil.frameTick.connect(onRequestAnimationFrame);
		lastTime = now();
	}

	@:noCompletion function _onWindowResize(event:Event) {
		width = Browser.window.innerWidth;
		height = Browser.window.innerHeight;
		renderer.resize(width, height);
		canvas.style.width = width + "px";
		canvas.style.height = height + "px";

		if (onResize != null) onResize();
	}

	@:noCompletion function onRequestAnimationFrame(_) {
		frameCount++;
		if (frameCount == Std.int(60 / fps)) {
			frameCount = 0;
			calculateElapsedTime();
			if (onUpdate != null) onUpdate(elapsedTime);
			renderer.render(stage);
		}
	}


	@:noCompletion inline function calculateElapsedTime() {
		currentTime = now();
		elapsedTime = currentTime - lastTime;
		lastTime = currentTime;
	}
}