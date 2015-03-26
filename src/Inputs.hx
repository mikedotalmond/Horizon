package;

import haxe.Timer;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.ui.Keyboard;
import openfl.Lib;
import openfl.ui.Mouse;

import hxsignal.Signal;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */
@:final class Inputs {
	
	public static inline var MouseVelocityEase	:Float = .8;
	public static inline var MouseVelocityMin	:Float = .00001;
	
	public static inline var MOUSE_IDLE_TIME	:Float = 4;
	public static inline var CLICK_TIME			:Float = .15;
	public static inline var DOUBLE_CLICK_TIME	:Float = .25;
	
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
	
	// square of mouse velocity - (dx * dx + dy * dy)
	public var mouseVelocity(default, null):Float = 0;
	
	public var enterFrame(default, null):Signal<Float->Float->Void>;
	
	var lastFrameTime	:Float 	= 0;
	var lastMouseX		:Float 	= 0;
	var lastMouseY		:Float 	= 0;
	
	
	public function new() {
		
		now = Timer.stamp();
	
		keyUp = new Signal<Int->Void>();
		keyDown = new Signal<Int->Void>();
		click = new Signal<Float->Float->Void>();
		doubleClick = new Signal<Float->Float->Void>();
		enterFrame = new Signal<Float->Float->Void>();
		mouseIdleChange = new Signal<Bool->Void>();
		
		mouseHasMoved = mouseIsDown = false;
		
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, onKey);
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKey);
		
		Lib.current.addEventListener(MouseEvent.MOUSE_UP, onMouse);
		Lib.current.addEventListener(MouseEvent.MOUSE_DOWN, onMouse);
		
		Lib.current.addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}
	
	
	function onKey(e:KeyboardEvent):Void {
		if (e.type == KeyboardEvent.KEY_DOWN) {
			keyDown.emit(e.keyCode);
		} else {
			keyUp.emit(e.keyCode);
		}
	}
	
	
	function onMouse(e:MouseEvent) {
		var wasDown = mouseIsDown;
		
		switch(e.type) {
			case MouseEvent.MOUSE_DOWN	: mouseIsDown = true;			
			case MouseEvent.MOUSE_UP	: mouseIsDown = false;
		}
		
		mouseX = e.stageX;
		mouseY = e.stageY;
		
		if (wasDown != mouseIsDown) checkClick();
	}
	
	var lastMouseUp:Float=0;
	var lastMouseDown:Float=0;
	function checkClick() {
		var now = Timer.stamp();
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
	
	
	function onEnterFrame(e:Event):Void {
		
		now 			= Timer.stamp();
		var dt 			= now - lastFrameTime;
		lastFrameTime 	= now;
		
		updateMouse(now);
		
		enterFrame.emit(now, dt);
		
		mouseHasMoved = false;
	}
	
	
	inline function updateMouse(now) {
		
		var mx = Lib.current.mouseX;
		var my = Lib.current.mouseY;
		
		mouseHasMoved 	= (mouseX != mx) || (mouseY != my);
		mouseX 			= mx;
		mouseY 			= my;
		
		if (mouseHasMoved) {
			mouseDeltaX = mx - lastMouseX;
			mouseDeltaY = my - lastMouseY;
			lastMouseX 	= mx;
			lastMouseY 	= my;
			
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
				Mouse.hide();
			}
		} else if (mouseIdle) {
			mouseIdle = false;
			mouseIdleChange.emit(mouseIdle);
			Mouse.show();
		}
	}
	
	
	/**
	 * 
	 * @param	lastTime - the time to compare `now` to (seconds)
	 * @return	time difference between lastTime and now
	 */
	public static inline function deltaTime(lastTime:Float):Float return Timer.stamp() - lastTime;
}