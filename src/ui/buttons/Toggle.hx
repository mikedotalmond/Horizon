package ui.buttons;

import hxsignal.Signal;

import motion.Actuate;
import motion.easing.Quad.QuadEaseIn;
import motion.easing.Quad.QuadEaseOut;

import openfl.Assets;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.MouseEvent;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

class Toggle extends Sprite {
	
	static inline var upAlpha = .2;
	static inline var downAlpha = .8;
	
	public var toggle(default, null):Signal<Bool->Void>;
	public var state(default, null):Bool = false;
	
	var onState	:BitmapData;
	var offState:BitmapData;
	var display	:Bitmap;
	var down	:Bool;
	
	public function new(inputs:Inputs, onStateAsset:String, offStateAsset:String) {
		super();
		
		toggle = new Signal<Bool->Void>();
		onState = Assets.getBitmapData(onStateAsset);
		offState = Assets.getBitmapData(offStateAsset);
		
		display = new Bitmap(onState);
		addChild(display);
		
		down = false;
		state = true;
		
		addEventListener(MouseEvent.CLICK, onMouse);
		addEventListener(MouseEvent.MOUSE_DOWN, onMouse);
		Lib.current.stage.addEventListener(MouseEvent.MOUSE_UP, onMouse);
		
		inputs.mouseIdleChange.connect(onMouseIdleChange);
		
		toggle.connect(onToggle);
		
		updateState();
	}
	
	public function setup(parent:Main, px:Float, py:Float) {
		display.alpha = 0;
		x = px - parent.x;
		y = py - parent.y;
		parent.addChild(this);
	}
	
	
	function onMouseIdleChange(idle:Bool) {
		if (idle) {
			Actuate.tween(display, 1.5, { alpha:0 } ).ease(new QuadEaseIn()).onComplete(function() {
				display.visible = false;
			});
		} else {
			display.visible = true;
			Actuate.tween(display, .25, { alpha:alphaForState() } ).ease(new QuadEaseOut());
		}
	}
	
	inline function alphaForState() {
		return down ? downAlpha : upAlpha;
	}
	
	function onToggle(state) {
		display.bitmapData = state ? onState : offState;
	}
	
	function onMouse(e:MouseEvent):Void {
		switch(e.type) {
			case MouseEvent.CLICK: toggle.emit(state = !state);
			case MouseEvent.MOUSE_DOWN: down = true;
			case MouseEvent.MOUSE_UP: down = false;
		}
		updateState();
	}
	
	function updateState() {
		if (down) display.alpha = downAlpha;
		else Actuate.tween(display, .5, { alpha:upAlpha } ).ease(new QuadEaseOut());
	}
}