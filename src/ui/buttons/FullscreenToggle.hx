package ui.buttons;

import ui.buttons.Toggle;
import util.Env;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */

class FullscreenToggle extends Toggle {
	
	public function new(inputs:Inputs) {
		super(inputs, 'img/exitfullscreen.png','img/fullscreen.png');
		toggle.connect(requestFullscreenChange);
	}
	
	override public function setup(parent:Main, px:Float, py:Float) {
		super.setup(parent, px, py);
		Env.fullscreenChange.connect(onFullscreenChange);
		toggle.emit(state = Env.isFullscreen);
	}
	
	function requestFullscreenChange(fullscreen:Bool) {
		if(Env.isFullscreen != fullscreen) Env.toggleFullscreen();
	}
	
	function onFullscreenChange(isFullscreen) {
		toggle.emit(state = isFullscreen);
	}
}
