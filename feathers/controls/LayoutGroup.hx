/*
Feathers
Copyright 2012-2014 Joshua Tynjala. All Rights Reserved.

This program is free software. You can redistribute and/or modify it in
accordance with the terms of the accompanying license agreement.
*/
package feathers.controls;
import feathers.core.FeathersControl;
import feathers.core.IFeathersControl;
import feathers.core.IValidating;
import feathers.events.FeathersEventType;
import feathers.layout.ILayout;
import feathers.layout.ILayoutDisplayObject;
import feathers.layout.IVirtualLayout;
import feathers.layout.LayoutBoundsResult;
import feathers.layout.ViewPortBounds;
import feathers.skins.IStyleProvider;

import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;

import starling.core.RenderSupport;
import starling.display.DisplayObject;
import starling.events.Event;

/**
 * A generic container that supports layout. For a container that supports
 * scrolling and more robust skinning options, see <code>ScrollContainer</code>.
 *
 * <p>The following example creates a layout group with a horizontal
 * layout and adds two buttons to it:</p>
 *
 * <listing version="3.0">
 * var group:LayoutGroup = new LayoutGroup();
 * var layout:HorizontalLayout = new HorizontalLayout();
 * layout.gap = 20;
 * layout.padding = 20;
 * group.layout = layout;
 * this.addChild( group );
 *
 * var yesButton:Button = new Button();
 * yesButton.label = "Yes";
 * group.addChild( yesButton );
 *
 * var noButton:Button = new Button();
 * noButton.label = "No";
 * group.addChild( noButton );</listing>
 *
 * @see http://wiki.starling-framework.org/feathers/layout-group
 * @see feathers.controls.ScrollContainer
 */
class LayoutGroup extends FeathersControl
{
	/**
	 * @private
	 */
	inline private static var HELPER_POINT:Point = new Point();

	/**
	 * @private
	 */
	inline private static var HELPER_MATRIX:Matrix = new Matrix();

	/**
	 * @private
	 */
	inline private static var INVALIDATION_FLAG_MXML_CONTENT:String = "mxmlContent";

	/**
	 * Flag to indicate that the clipping has changed.
	 */
	inline private static var INVALIDATION_FLAG_CLIPPING:String = "clipping";

	/**
	 * The default <code>IStyleProvider</code> for all <code>LayoutGroup</code>
	 * components.
	 *
	 * @default null
	 * @see feathers.core.FeathersControl#styleProvider
	 */
	public static var globalStyleProvider:IStyleProvider;

	/**
	 * Constructor.
	 */
	public function LayoutGroup()
	{
		super();
	}

	/**
	 * The items added to the group.
	 */
	private var items:Vector.<DisplayObject> = new <DisplayObject>[];

	/**
	 * The view port bounds result object passed to the layout. Its values
	 * should be set in <code>refreshViewPortBounds()</code>.
	 */
	private var viewPortBounds:ViewPortBounds = new ViewPortBounds();

	/**
	 * @private
	 */
	private var _layoutResult:LayoutBoundsResult = new LayoutBoundsResult();

	/**
	 * @private
	 */
	override private function get_defaultStyleProvider():IStyleProvider
	{
		return LayoutGroup.globalStyleProvider;
	}

	/**
	 * @private
	 */
	private var _layout:ILayout;

	/**
	 * Controls the way that the group's children are positioned and sized.
	 *
	 * <p>The following example tells the group to use a horizontal layout:</p>
	 *
	 * <listing version="3.0">
	 * var layout:HorizontalLayout = new HorizontalLayout();
	 * layout.gap = 20;
	 * layout.padding = 20;
	 * container.layout = layout;</listing>
	 *
	 * @default null
	 */
	public function get_layout():ILayout
	{
		return this._layout;
	}

	/**
	 * @private
	 */
	public function set_layout(value:ILayout):Void
	{
		if(this._layout == value)
		{
			return;
		}
		if(this._layout)
		{
			this._layout.removeEventListener(Event.CHANGE, layout_changeHandler);
		}
		this._layout = value;
		if(this._layout)
		{
			if(this._layout is IVirtualLayout)
			{
				IVirtualLayout(this._layout).useVirtualLayout = false;
			}
			this._layout.addEventListener(Event.CHANGE, layout_changeHandler);
			//if we don't have a layout, nothing will need to be redrawn
			this.invalidate(INVALIDATION_FLAG_LAYOUT);
		}
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
	}

	/**
	 * @private
	 */
	private var _mxmlContentIsReady:Bool = false;

	/**
	 * @private
	 */
	private var _mxmlContent:Array;

	[ArrayElementType("feathers.core.IFeathersControl")]
	/**
	 * @private
	 */
	public function get_mxmlContent():Array
	{
		return this._mxmlContent;
	}

	/**
	 * @private
	 */
	public function set_mxmlContent(value:Array):Void
	{
		if(this._mxmlContent == value)
		{
			return;
		}
		if(this._mxmlContent && this._mxmlContentIsReady)
		{
			var childCount:Int = this._mxmlContent.length;
			for(var i:Int = 0; i < childCount; i++)
			{
				var child:DisplayObject = DisplayObject(this._mxmlContent[i]);
				this.removeChild(child, true);
			}
		}
		this._mxmlContent = value;
		this._mxmlContentIsReady = false;
		this.invalidate(INVALIDATION_FLAG_MXML_CONTENT);
	}

	/**
	 * @private
	 */
	private var _clipContent:Bool = false;

	/**
	 * If true, the group will be clipped to its bounds. In other words,
	 * anything appearing beyond the edges of the group will be masked or
	 * hidden.
	 *
	 * <p>Since <code>LayoutGroup</code> is designed to be a light
	 * container focused on performance, clipping is disabled by default.</p>
	 *
	 * <p>In the following example, clipping is enabled:</p>
	 *
	 * <listing version="3.0">
	 * group.clipContent = true;</listing>
	 *
	 * @default false
	 */
	public function get_clipContent():Bool
	{
		return this._clipContent;
	}

	/**
	 * @private
	 */
	public function set_clipContent(value:Bool):Void
	{
		if(this._clipContent == value)
		{
			return;
		}
		this._clipContent = value;
		this.invalidate(INVALIDATION_FLAG_CLIPPING);
	}

	/**
	 * @private
	 */
	private var originalBackgroundWidth:Float = NaN;

	/**
	 * @private
	 */
	private var originalBackgroundHeight:Float = NaN;

	/**
	 * @private
	 */
	private var currentBackgroundSkin:DisplayObject;

	/**
	 * @private
	 */
	private var _backgroundSkin:DisplayObject;

	/**
	 * The default background to display behind all content. The background
	 * skin is resized to fill the full width and height of the layout
	 * group.
	 *
	 * <p>In the following example, the group is given a background skin:</p>
	 *
	 * <listing version="3.0">
	 * group.backgroundSkin = new Image( texture );</listing>
	 *
	 * @default null
	 */
	public function get_backgroundSkin():DisplayObject
	{
		return this._backgroundSkin;
	}

	/**
	 * @private
	 */
	public function set_backgroundSkin(value:DisplayObject):Void
	{
		if(this._backgroundSkin == value)
		{
			return;
		}
		this._backgroundSkin = value;
		this.invalidate(INVALIDATION_FLAG_SKIN);
	}

	/**
	 * @private
	 */
	private var _backgroundDisabledSkin:DisplayObject;

	/**
	 * The background to display behind all content when the layout group is
	 * disabled. The background skin is resized to fill the full width and
	 * height of the layout group.
	 *
	 * <p>In the following example, the group is given a background skin:</p>
	 *
	 * <listing version="3.0">
	 * group.backgroundDisabledSkin = new Image( texture );</listing>
	 *
	 * @default null
	 */
	public function get_backgroundDisabledSkin():DisplayObject
	{
		return this._backgroundDisabledSkin;
	}

	/**
	 * @private
	 */
	public function set_backgroundDisabledSkin(value:DisplayObject):Void
	{
		if(this._backgroundDisabledSkin == value)
		{
			return;
		}
		this._backgroundDisabledSkin = value;
		this.invalidate(INVALIDATION_FLAG_SKIN);
	}

	/**
	 * @private
	 */
	private var _ignoreChildChanges:Bool = false;

	/**
	 * @private
	 */
	override public function addChildAt(child:DisplayObject, index:Int):DisplayObject
	{
		if(child is IFeathersControl)
		{
			child.addEventListener(FeathersEventType.RESIZE, child_resizeHandler);
		}
		if(child is ILayoutDisplayObject)
		{
			child.addEventListener(FeathersEventType.LAYOUT_DATA_CHANGE, child_layoutDataChangeHandler);
		}
		var oldIndex:Int = this.items.indexOf(child);
		if(oldIndex == index)
		{
			return child;
		}
		if(oldIndex >= 0)
		{
			this.items.splice(oldIndex, 1);
		}
		var itemCount:Int = this.items.length;
		if(index == itemCount)
		{
			//faster than splice because it avoids gc
			this.items[index] = child;
		}
		else
		{
			this.items.splice(index, 0, child);
		}
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
		return super.addChildAt(child, index);
	}

	/**
	 * @private
	 */
	override public function removeChildAt(index:Int, dispose:Bool = false):DisplayObject
	{
		var child:DisplayObject = super.removeChildAt(index, dispose);
		if(child is IFeathersControl)
		{
			child.removeEventListener(FeathersEventType.RESIZE, child_resizeHandler);
		}
		if(child is ILayoutDisplayObject)
		{
			child.removeEventListener(FeathersEventType.LAYOUT_DATA_CHANGE, child_layoutDataChangeHandler);
		}
		this.items.splice(index, 1);
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
		return child;
	}

	/**
	 * @private
	 */
	override public function setChildIndex(child:DisplayObject, index:Int):Void
	{
		super.setChildIndex(child, index);
		var oldIndex:Int = this.items.indexOf(child);
		if(oldIndex == index)
		{
			return;
		}

		//the super function already checks if oldIndex < 0, and throws an
		//appropriate error, so no need to do it again!

		this.items.splice(oldIndex, 1);
		this.items.splice(index, 0, child);
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
	}

	/**
	 * @private
	 */
	override public function swapChildrenAt(index1:Int, index2:Int):Void
	{
		super.swapChildrenAt(index1, index2)
		var child1:DisplayObject = this.items[index1];
		var child2:DisplayObject = this.items[index2];
		this.items[index1] = child2;
		this.items[index2] = child1;
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
	}

	/**
	 * @private
	 */
	override public function sortChildren(compareFunction:Function):Void
	{
		super.sortChildren(compareFunction);
		this.items.sort(compareFunction);
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
	}

	/**
	 * @private
	 */
	override public function hitTest(localPoint:Point, forTouch:Bool = false):DisplayObject
	{
		var localX:Float = localPoint.x;
		var localY:Float = localPoint.y;
		var result:DisplayObject = super.hitTest(localPoint, forTouch);
		if(result)
		{
			if(!this._isEnabled)
			{
				return this;
			}
			return result;
		}
		if(this.currentBackgroundSkin && this._hitArea.contains(localX, localY))
		{
			return this;
		}
		return null;
	}

	/**
	 * @private
	 */
	override public function render(support:RenderSupport, parentAlpha:Float):Void
	{
		if(this.currentBackgroundSkin && this.currentBackgroundSkin.hasVisibleArea)
		{
			var blendMode:String = this.blendMode;
			support.pushMatrix();
			support.transformMatrix(this.currentBackgroundSkin);
			support.blendMode = this.currentBackgroundSkin.blendMode;
			this.currentBackgroundSkin.render(support, parentAlpha * this.alpha);
			support.blendMode = blendMode;
			support.popMatrix();
		}
		super.render(support, parentAlpha);
	}

	/**
	 * @private
	 */
	override public function dispose():Void
	{
		this.layout = null;
		super.dispose();
	}

	/**
	 * Readjusts the layout of the group according to its current content.
	 * Call this method when changes to the content cannot be automatically
	 * detected by the container. For instance, Feathers components dispatch
	 * <code>FeathersEventType.RESIZE</code> when their width and height
	 * values change, but standard Starling display objects like
	 * <code>Sprite</code> and <code>Image</code> do not.
	 */
	public function readjustLayout():Void
	{
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
	}

	/**
	 * @private
	 */
	override private function initialize():Void
	{
		this.refreshMXMLContent();
	}

	/**
	 * @private
	 */
	override private function draw():Void
	{
		var layoutInvalid:Bool = this.isInvalid(INVALIDATION_FLAG_LAYOUT);
		var sizeInvalid:Bool = this.isInvalid(INVALIDATION_FLAG_SIZE);
		var clippingInvalid:Bool = this.isInvalid(INVALIDATION_FLAG_CLIPPING);
		//we don't have scrolling, but a subclass might
		var scrollInvalid:Bool = this.isInvalid(INVALIDATION_FLAG_SCROLL);
		var skinInvalid:Bool = this.isInvalid(INVALIDATION_FLAG_SKIN);
		var stateInvalid:Bool = this.isInvalid(INVALIDATION_FLAG_STATE);

		//scrolling only affects the layout is requiresLayoutOnScroll is true
		if(!layoutInvalid && scrollInvalid && this._layout && this._layout.requiresLayoutOnScroll)
		{
			layoutInvalid = true;
		}

		if(skinInvalid || stateInvalid)
		{
			this.refreshBackgroundSkin();
		}

		if(sizeInvalid || layoutInvalid || skinInvalid || stateInvalid)
		{
			this.refreshViewPortBounds();
			if(this._layout)
			{
				this._ignoreChildChanges = true;
				this._layout.layout(this.items, this.viewPortBounds, this._layoutResult);
				this._ignoreChildChanges = false;
			}
			else
			{
				this.handleManualLayout();
			}
			var width:Float = this._layoutResult.contentWidth;
			if(this.originalBackgroundWidth === this.originalBackgroundWidth && //!isNaN
				this.originalBackgroundWidth > width)
			{
				width = this.originalBackgroundWidth;
			}
			var height:Float = this._layoutResult.contentHeight;
			if(this.originalBackgroundHeight === this.originalBackgroundHeight && //!isNaN
				this.originalBackgroundHeight > height)
			{
				height = this.originalBackgroundHeight;
			}
			sizeInvalid = this.setSizeInternal(width, height, false) || sizeInvalid;
			if(this.currentBackgroundSkin)
			{
				this.currentBackgroundSkin.width = this.actualWidth;
				this.currentBackgroundSkin.height = this.actualHeight;
			}

			//final validation to avoid juggler next frame issues
			this.validateChildren();
		}

		if(sizeInvalid || clippingInvalid)
		{
			this.refreshClipRect();
		}
	}

	/**
	 * Choose the appropriate background skin based on the control's current
	 * state.
	 */
	private function refreshBackgroundSkin():Void
	{
		if(!this._isEnabled && this._backgroundDisabledSkin)
		{
			this.currentBackgroundSkin = this._backgroundDisabledSkin;
		}
		else
		{
			this.currentBackgroundSkin = this._backgroundSkin
		}
		if(this.currentBackgroundSkin)
		{
			if(this.originalBackgroundWidth !== this.originalBackgroundWidth ||
				this.originalBackgroundHeight !== this.originalBackgroundHeight) //isNaN
			{
				if(this.currentBackgroundSkin is IValidating)
				{
					IValidating(this.currentBackgroundSkin).validate();
				}
				this.originalBackgroundWidth = this.currentBackgroundSkin.width;
				this.originalBackgroundHeight = this.currentBackgroundSkin.height;
			}
		}
	}

	/**
	 * Refreshes the values in the <code>viewPortBounds</code> variable that
	 * is passed to the layout.
	 */
	private function refreshViewPortBounds():Void
	{
		this.viewPortBounds.x = 0;
		this.viewPortBounds.y = 0;
		this.viewPortBounds.scrollX = 0;
		this.viewPortBounds.scrollY = 0;
		this.viewPortBounds.explicitWidth = this.explicitWidth;
		this.viewPortBounds.explicitHeight = this.explicitHeight;
		this.viewPortBounds.minWidth = this._minWidth;
		this.viewPortBounds.minHeight = this._minHeight;
		this.viewPortBounds.maxWidth = this._maxWidth;
		this.viewPortBounds.maxHeight = this._maxHeight;
	}

	/**
	 * @private
	 */
	private function handleManualLayout():Void
	{
		var maxX:Float = this.viewPortBounds.explicitWidth;
		if(maxX !== maxX) //isNaN
		{
			maxX = 0;
		}
		var maxY:Float = this.viewPortBounds.explicitHeight;
		if(maxY !== maxY) //isNaN
		{
			maxY = 0;
		}
		this._ignoreChildChanges = true;
		var itemCount:Int = this.items.length;
		for(var i:Int = 0; i < itemCount; i++)
		{
			var item:DisplayObject = this.items[i];
			if(item is ILayoutDisplayObject && !ILayoutDisplayObject(item).includeInLayout)
			{
				continue;
			}
			if(item is IValidating)
			{
				IValidating(item).validate();
			}
			var itemMaxX:Float = item.x + item.width;
			var itemMaxY:Float = item.y + item.height;
			if(itemMaxX === itemMaxX && //!isNaN
				itemMaxX > maxX)
			{
				maxX = itemMaxX;
			}
			if(itemMaxY === itemMaxY && //!isNaN
				itemMaxY > maxY)
			{
				maxY = itemMaxY;
			}
		}
		this._ignoreChildChanges = false;
		this._layoutResult.contentX = 0;
		this._layoutResult.contentY = 0;
		this._layoutResult.contentWidth = maxX;
		this._layoutResult.contentHeight = maxY;
		this._layoutResult.viewPortWidth = maxX;
		this._layoutResult.viewPortHeight = maxY;
	}

	/**
	 * @private
	 */
	private function validateChildren():Void
	{
		if(this.currentBackgroundSkin is IValidating)
		{
			IValidating(this.currentBackgroundSkin).validate();
		}
		var itemCount:Int = this.items.length;
		for(var i:Int = 0; i < itemCount; i++)
		{
			var item:DisplayObject = this.items[i];
			if(item is IValidating)
			{
				IValidating(item).validate();
			}
		}
	}

	/**
	 * @private
	 */
	private function refreshMXMLContent():Void
	{
		if(!this._mxmlContent || this._mxmlContentIsReady)
		{
			return;
		}
		var childCount:Int = this._mxmlContent.length;
		for(var i:Int = 0; i < childCount; i++)
		{
			var child:DisplayObject = DisplayObject(this._mxmlContent[i]);
			this.addChild(child);
		}
		this._mxmlContentIsReady = true;
	}

	/**
	 * @private
	 */
	private function refreshClipRect():Void
	{
		if(this._clipContent)
		{
			if(!this.clipRect)
			{
				this.clipRect = new Rectangle();
			}

			var clipRect:Rectangle = this.clipRect;
			clipRect.x = 0;
			clipRect.y = 0;
			clipRect.width = this.actualWidth;
			clipRect.height = this.actualHeight;
			this.clipRect = clipRect;
		}
		else
		{
			this.clipRect = null;
		}
	}

	/**
	 * @private
	 */
	private function layout_changeHandler(event:Event):Void
	{
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
	}

	/**
	 * @private
	 */
	private function child_resizeHandler(event:Event):Void
	{
		if(this._ignoreChildChanges)
		{
			return;
		}
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
	}

	/**
	 * @private
	 */
	private function child_layoutDataChangeHandler(event:Event):Void
	{
		if(this._ignoreChildChanges)
		{
			return;
		}
		this.invalidate(INVALIDATION_FLAG_LAYOUT);
	}
}