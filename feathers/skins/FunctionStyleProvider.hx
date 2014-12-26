/*
Feathers
Copyright 2012-2014 Joshua Tynjala. All Rights Reserved.

This program is free software. You can redistribute and/or modify it in
accordance with the terms of the accompanying license agreement.
*/
package feathers.skins;
import feathers.core.IFeathersControl;

/**
 * Sets styles on a Feathers UI component by passing the component to a
 * function when the style provider's <code>applyStyles()</code> is called.
 *
 * <p>In the following example, a <code>FunctionStyleProvider</code> is
 * created:</p>
 * <listing version="3.0">
 * var button:Button = new Button();
 * button.label = "Click Me";
 * button.styleProvider = new FunctionStyleProvider( function( target:Button ):Void
 * {
 *     target.defaultSkin = new Image( texture );
 *     // set other styles...
 * });
 * this.addChild( button );</listing>
 */
class FunctionStyleProvider implements IStyleProvider
{
	/**
	 * Constructor.
	 */
	public function FunctionStyleProvider(skinFunction:Function)
	{
		this._styleFunction = skinFunction;
	}

	/**
	 * @private
	 */
	private var _styleFunction:Function;

	/**
	 * The target Feathers UI component is passed to this function when
	 * <code>applyStyles()</code> is called.
	 *
	 * <p>The function is expected to have the following signature:</p>
	 * <pre>function( item:IFeathersControl ):Void</pre>
	 */
	public function get_styleFunction():Function
	{
		return this._styleFunction;
	}

	/**
	 * @private
	 */
	public function set_styleFunction(value:Function):Void
	{
		this._styleFunction = value;
	}

	/**
	 * @inheritDoc
	 */
	public function applyStyles(target:IFeathersControl):Void
	{
		if(this._styleFunction == null)
		{
			return;
		}
		this._styleFunction(target);
	}
}