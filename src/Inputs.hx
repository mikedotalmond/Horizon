package;

import haxe.Timer;
import js.Browser;
import js.html.Event;
import js.html.KeyboardEvent;
import js.html.TouchEvent;
import pixi.core.display.Container;
import pixi.interaction.EventTarget;
import tones.utils.TimeUtil;

import hxsignal.Signal;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */
@:final class Inputs {
	
	public static inline var MouseVelocityEase	:Float = .8;
	public static inline var MouseVelocityMin	:Float = .00001;
	
	public static inline var MOUSE_IDLE_TIME	:Float = 4000;
	public static inline var CLICK_TIME			:Float = 150;
	public static inline var DOUBLE_CLICK_TIME	:Float = 250;
	
	public var keyUp(default, null):Signal<Int->Void>;
	public var keyDown(default, null):Signal<Int->Void>;
	
	public var click(default, null):Signal<Float->Float->Void>;
	public var doubleClick(default, null):Signal<Float->Float->Void>;
	
	public var now(default, null):Float;
	
	public var mouseIsDown(default, null):Bool;
	public var mouseHasMoved(default, null):Bool;
	public var lastMouseMove(default, null):Float = 0;
	public var lastMouseMoveWhileHeld(default, null):Float = 0;
	
	public var mouseX(default, null):Float = 0;
	public var mouseY(default, null):Float = 0;
	public var mouseDeltaX(default, null):Float = 0;
	public var mouseDeltaY(default, null):Float = 0;
	
	public var mouseIdle(default, null):Bool = false;
	public var mouseIdleChange(default, null):Signal<Bool->Void>;
	public var hidePointerWhenIdle:Bool = false;
	
	// square of mouse velocity - (dx * dx + dy * dy)
	public var mouseVelocity(default, null):Float = 0;
	
	var lastMouseX		:Float = 0;
	var lastMouseY		:Float = 0;
	var lastMouseUp		:Float=0;
	var lastMouseDown	:Float=0;
	var stage			:Container;
	
	public function new(stage:Container) {
		
		this.stage = stage;
		stage.interactive = true;
		
		keyUp = new Signal<Int->Void>();
		keyDown = new Signal<Int->Void>();
		click = new Signal<Float->Float->Void>();
		doubleClick = new Signal<Float->Float->Void>();
		mouseIdleChange = new Signal<Bool->Void>();
		
		mouseHasMoved = mouseIsDown = false;
		
		stage.on('mousedown', onMouse);
		stage.on('touchstart', onMouse);
		stage.on('mouseup', onMouse);
		stage.on('touchend', onMouse);
		stage.on('mousemove', onMouse);
		stage.on('touchmove', onMouse);
		
		Browser.document.onkeydown = onKey;
		Browser.document.onkeyup = onKey;
	}
	
	
	function onKey(e:KeyboardEvent):Void {
		if (e.type == 'keydown') {
			keyDown.emit(e.keyCode);
		} else {
			keyUp.emit(e.keyCode);
		}
	}
	
	
	function onMouse(e:EventTarget) {
		var wasDown = mouseIsDown;
		
		switch(e.type) {
			case 'mouseup', 'touchend' : mouseIsDown = false;
			case 'mousedown', 'touchstart' : mouseIsDown = true;			
			case 'mousemove', 'touchmove' : mouseHasMoved = true;
		}
		
		var pt = e.data.global;
		lastMouseX = mouseX;
		lastMouseY = mouseY;
		mouseX = pt.x;
		mouseY = pt.y;
		
		if (wasDown != mouseIsDown) checkClick();
	}
	
	function checkClick() {
		var now = TimeUtil.now;
		if (mouseIsDown) {
			lastMouseDown = now;
		} else {
			if (now - lastMouseUp < DOUBLE_CLICK_TIME) { //
				lastMouseUp = 0;
				doubleClick.emit(mouseX, mouseY);
			} else if (now - lastMouseDown < CLICK_TIME) {
				click.emit(mouseX, mouseY);
			}
			lastMouseUp = now;
		}
	}
	
	public function update(elapsed:Float):Void {
		updateMouse(elapsed);
		mouseHasMoved = false;
	}
	
	inline function updateMouse(now) {
		
		if (mouseHasMoved) {
			mouseDeltaX = mouseX - lastMouseX;
			mouseDeltaY = mouseY - lastMouseY;
			lastMouseMove = now;
			if (mouseIsDown) lastMouseMoveWhileHeld = now;
			
		} else {
			mouseDeltaX = mouseDeltaY = 0;
		}
		
		var mVel = mouseDeltaX * mouseDeltaX + mouseDeltaY * mouseDeltaY;
		mouseVelocity += (mVel - mouseVelocity) * MouseVelocityEase;
		
		var abs = mouseVelocity < 0 ? -mouseVelocity : mouseVelocity;
		if (abs < MouseVelocityMin)  mouseVelocity = 0;
		if (now - lastMouseMove > MOUSE_IDLE_TIME) {
			if (!mouseIdle) {
				mouseIdle = true;
				mouseIdleChange.emit(mouseIdle);
				if(hidePointerWhenIdle) Browser.document.body.style.cursor = "none";
			}
		} else if (mouseIdle) {
			mouseIdle = false;
			mouseIdleChange.emit(mouseIdle);
			Browser.document.body.style.cursor = "";
		}
	}
	
	
	/**
	 * 
	 * @param	lastTime - the time to compare `now` to (seconds)
	 * @return	time difference between lastTime and now
	 */
	public static inline function deltaTime(lastTime:Float):Float return Timer.stamp() - lastTime;
}