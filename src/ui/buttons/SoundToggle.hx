package ui.buttons;
import ui.buttons.Toggle;

/**
 * ...
 * @author Mike Almond - https://github.com/mikedotalmond
 */
class SoundToggle extends Toggle {
	public function new(inputs:Inputs) {
		super(inputs, 'img/audioOn.png', 'img/audioOff.png');
	}
}