//
//  WindowButtonBar.swift
//  Helium
//
//  Created by Carlos D. Santiago on 12/13/18
//  Copyright © 2018 Carlos D. Santiaog. All rights reserved.
//
//	WindowButtonBar.swift - https://gist.github.com/icodeforlove/a334884e59784b4c2567
//	Custom implementation of the OSX Yosemite close, miniaturize, zoom buttons.
//
//	Enhanced to adopt individual button image
import Foundation

class WindowButton: NSButton {
	private var _individualized:Bool = false;
	private var _isMouseOver:Bool = false;
	private var useTrackingArea:Bool = true;
	
	var isMouseOver:Bool {
		set {
			self._isMouseOver = newValue;
			self.setNeedsDisplay();
		}
		get {
			return self._isMouseOver;
		}
	};
	var individualized:Bool {
		set {
			self._individualized = newValue;
			self.setNeedsDisplay();
		}
		get {
			return self._individualized;
		}
	}
	var type:NSWindowButton = NSWindowButton.miniaturizeButton;
	
	
	init(frame:NSRect, type:NSWindowButton, useTrackingArea:Bool = true) {
		super.init(frame: frame);
		
		self.type = type;
		self.target = self;
		self.action = #selector(WindowButton.onClick);
		self.useTrackingArea = useTrackingArea;
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder);
		
		self.target = self;
		self.action = #selector(WindowButton.onClick);
	}
	
	func onClick () {
		if (type == NSWindowButton.zoomButton) {
			self.window?.zoom(self);
		} else if (type == NSWindowButton.miniaturizeButton) {
			self.window?.miniaturize(self);
		} else if (type == NSWindowButton.closeButton) {
			self.window?.close();
		}
	}
	
	override func updateTrackingAreas() {
		if (self.useTrackingArea) {
			let options:NSTrackingAreaOptions = NSTrackingAreaOptions.activeInActiveApp
				.union(NSTrackingAreaOptions.mouseEnteredAndExited)
				.union(NSTrackingAreaOptions.assumeInside)
				.union(NSTrackingAreaOptions.inVisibleRect);
			
			let trackingArea = NSTrackingArea(rect: self.bounds, options:options, owner: self, userInfo: nil);
			self.addTrackingArea(trackingArea);
		}
	}
	
	override func mouseEntered(with theEvent: NSEvent) {
		if (self.useTrackingArea) {
			self.isMouseOver = true;
		}
	}
	override func mouseExited(with theEvent: NSEvent) {
		if (self.useTrackingArea) {
			self.isMouseOver = true;
		}
	}
	
	override func draw(_ dirtyRect: NSRect) {
		NSGraphicsContext.current()?.saveGraphicsState();
		if let image = self.image {
			image.draw(in: dirtyRect)
		}
		else
		{
			var backgroundGradient:NSGradient?;
			var strokeColor:NSColor?;
			var lineColor:NSColor?;
		
			if (type == NSWindowButton.zoomButton) {
				backgroundGradient = NSGradient(
					starting: NSColor(red: 0.153, green: 0.788, blue: 0.247, alpha: 1),
					ending: NSColor(red: 0.153, green: 0.816, blue: 0.255, alpha: 1))!;
				
				lineColor = NSColor(red: 0.004, green: 0.392, blue: 0, alpha: 1);
				strokeColor = NSColor(red: 0.180, green: 0.690, blue: 0.235, alpha: 1);
			} else if (type == NSWindowButton.miniaturizeButton) {
				backgroundGradient = NSGradient(
					starting: NSColor(red: 1, green: 0.741, blue: 0.180, alpha: 1),
					ending: NSColor(red: 1, green: 0.773, blue: 0.184, alpha: 1))!;
				
				lineColor = NSColor(red: 0.600, green: 0.345, blue: 0.004, alpha: 1);
				strokeColor = NSColor(red: 0.875, green: 0.616, blue: 0.094, alpha: 1);
			} else if (type == NSWindowButton.closeButton) {
				backgroundGradient = NSGradient(
					starting: NSColor(red: 1, green: 0.373, blue: 0.337, alpha: 1),
					ending: NSColor(red: 1, green: 0.388, blue: 0.357, alpha: 1))!;
				
				lineColor = NSColor(red: 0.302, green: 0, blue: 0, alpha: 1);
				strokeColor = NSColor(red: 0.886, green: 0.243, blue: 0.216, alpha: 1);
			}
		
			// draw background
			var path = NSBezierPath();
		
			path.appendOval(in: NSMakeRect(self.bounds.origin.x + 0.5, self.bounds.origin.y + 0.5, self.bounds.width - 1, self.bounds.height - 1));
		
			backgroundGradient?.draw(in: path, relativeCenterPosition: NSMakePoint(0, 0));
			strokeColor?.setStroke();
			path.lineWidth = 2.5;
			path.stroke();
		
			if (self.isHighlighted) {
				NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0.2).setFill();
				path.fill();
			}
		
			// draw contents
			if (self.isMouseOver) {
				path = NSBezierPath();
				
				if (type == NSWindowButton.zoomButton) {
					NSGraphicsContext.current()?.shouldAntialias = false;
					path.move(to: NSMakePoint(self.bounds.width / 2, self.bounds.height * 0.20));
					path.line(to: NSMakePoint(self.bounds.width / 2, self.bounds.height * 0.80));
					
					path.move(to: NSMakePoint(self.bounds.width * 0.80, self.bounds.height / 2));
					path.line(to: NSMakePoint(self.bounds.width * 0.20, self.bounds.height / 2));
					path.lineWidth = 0.75;
				} else if (type == NSWindowButton.miniaturizeButton) {
					NSGraphicsContext.current()?.shouldAntialias = false;
					
					path.move(to: NSMakePoint(self.bounds.width * 0.80, self.bounds.height / 2));
					path.line(to: NSMakePoint(self.bounds.width * 0.20, self.bounds.height / 2));
					path.lineWidth = 0.75;
				} else if (type == NSWindowButton.closeButton) {
					path.move(to: NSMakePoint(self.bounds.width * 0.30, self.bounds.height * 0.30));
					path.line(to: NSMakePoint(self.bounds.width * 0.70, self.bounds.height * 0.70));
					
					path.move(to: NSMakePoint(self.bounds.width * 0.70, self.bounds.height * 0.30));
					path.line(to: NSMakePoint(self.bounds.width * 0.30, self.bounds.height * 0.70));
					path.lineWidth = 1;
				}
				
				lineColor?.setStroke();
				path.stroke();
			}
		}
		NSGraphicsContext.current()?.restoreGraphicsState();
	}
}

public class WindowButtonBar:NSView {
	var closeButton:WindowButton?;
	var miniaturizeButton:WindowButton?;
	var zoomButton:WindowButton?;
	
	required public init?(coder: NSCoder) {
		super.init(coder: coder);
		self.setupViews();
	}
	
	override init (frame:NSRect) {
		super.init(frame: frame);
		self.setupViews();
	}
	
	func setupViews () {
		self.closeButton = WindowButton(frame: NSMakeRect(0, 0, 13, 13), type: NSWindowButton.closeButton, useTrackingArea: false);
		self.miniaturizeButton = WindowButton(frame: NSMakeRect(20, 0, 13, 13), type: NSWindowButton.miniaturizeButton, useTrackingArea: false);
		self.zoomButton = WindowButton(frame: NSMakeRect(40, 0, 13, 13), type: NSWindowButton.zoomButton, useTrackingArea: false);
		
		self.addSubview(self.closeButton!);
		self.addSubview(self.miniaturizeButton!);
		self.addSubview(self.zoomButton!);
		
		let trackingArea = NSTrackingArea(rect: self.bounds, options: NSTrackingAreaOptions.mouseEnteredAndExited.union(NSTrackingAreaOptions.mouseMoved).union(NSTrackingAreaOptions.activeAlways), owner: self, userInfo: nil);
		self.addTrackingArea(trackingArea);
	}
	
	override public func mouseEntered(with theEvent: NSEvent) {
		self.closeButton?.isMouseOver = true;
		self.miniaturizeButton?.isMouseOver = true;
		self.zoomButton?.isMouseOver = true;
	}
	
	override public func mouseExited(with theEvent: NSEvent) {
		self.closeButton?.isMouseOver = false;
		self.miniaturizeButton?.isMouseOver = false;
		self.zoomButton?.isMouseOver = false;
	}
}
