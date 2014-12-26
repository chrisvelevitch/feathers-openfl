/*
Feathers
Copyright 2012-2014 Joshua Tynjala. All Rights Reserved.

This program is free software. You can redistribute and/or modify it in
accordance with the terms of the accompanying license agreement.
*/
package feathers.controls;
import feathers.core.IFeathersControl;

/**
 * A screen for use with <code>ScreenNavigator</code>.
 *
 * @see ScreenNavigator
 * @see ScreenNavigatorItem
 */
public interface IScreen extends IFeathersControl
{
	/**
	 * The identifier for the screen. This value is passed in by the
	 * <code>ScreenNavigator</code> when the screen is instantiated.
	 */
	function get_screenID():String;

	/**
	 * @private
	 */
	function set_screenID(value:String):Void;

	/**
	 * The ScreenNavigator that is displaying this screen.
	 */
	function get_owner():ScreenNavigator;

	/**
	 * @private
	 */
	function set_owner(value:ScreenNavigator):Void;
}