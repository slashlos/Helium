//
//  PanelButtonBar.swift
//  Helium
//
//  Created by Carlos D. Santiago on 12/13/18
//  Copyright © 2018 Carlos D. Santiaog. All rights reserved.
//
//	WindowButtonBar.swift - https://gist.github.com/icodeforlove/a334884e59784b4c2567
//	Custom implementation of the OSX Yosemite close, miniaturize, zoom buttons.
//

import Foundation

class PanelButton : NSButton {
	private var _isMouseOver:Bool = false;
	private var useTrackingArea:Bool = true;
	private var buttonBar : PanelButtonBar {
		get {
			return self.superview as! PanelButtonBar
		}
	}
	var isMouseOver:Bool {
		set {
			self._isMouseOver = newValue;
			self.setNeedsDisplay();
		}
		get {
			return self._isMouseOver;
		}
	};
	var type:NSWindow.ButtonType = NSWindow.ButtonType.miniaturizeButton;
	
	
	init(frame:NSRect, type:NSWindow.ButtonType, useTrackingArea:Bool = true) {
		super.init(frame: frame);
		
		self.type = type;
		self.target = self;
		self.action = #selector(PanelButton.onClick);
		self.useTrackingArea = useTrackingArea;
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder);
		
		self.target = self;
		self.action = #selector(PanelButton.onClick);
	}
	
	@objc func onClick () {
		if (type == NSWindow.ButtonType.closeButton), let target = self.target, let action = self.action {
			_ = target.perform(action, with: self)
		}
		else
		{
			if (type == NSWindow.ButtonType.zoomButton) {
				self.window?.zoom(self);
			} else if (type == NSWindow.ButtonType.miniaturizeButton) {
				self.window?.miniaturize(self);
			} else if (type == NSWindow.ButtonType.closeButton) {
				self.window?.close();
			}
		}
	}
	
	override func updateTrackingAreas() {
		if (self.useTrackingArea) {
			let options:NSTrackingArea.Options = NSTrackingArea.Options.activeInActiveApp
				.union(NSTrackingArea.Options.mouseEnteredAndExited)
				.union(NSTrackingArea.Options.assumeInside)
				.union(NSTrackingArea.Options.inVisibleRect);
			
			let trackingArea = NSTrackingArea(rect: self.bounds, options:options, owner: self, userInfo: nil)
			self.addTrackingArea(trackingArea)
		}
	}
	
	override func mouseEntered(with theEvent: NSEvent) {
		if (self.useTrackingArea) {
			self.isMouseOver = true;
		}
	}
	override func mouseExited(with theEvent: NSEvent) {
		if (self.useTrackingArea) {
			self.isMouseOver = !buttonBar.individualized
		}
	}
	
	override func draw(_ dirtyRect: NSRect) {
		if self.isHidden || !self.isMouseOver { return }
		NSGraphicsContext.current?.saveGraphicsState();
		var path = NSBezierPath();

		if let image = self.image {
			image.draw(in: dirtyRect)
		}
		else
		{
			//	all buttons are monochrome coloring and gradient
			let backgroundGradient = NSGradient(starting:NSColor.white, ending: NSColor.white)!;
			let strokeColor = NSColor.white
			let lineColor = NSColor.black
			
			// draw background for close, mini, zoom
			path.appendOval(in: NSMakeRect(self.bounds.origin.x + 0.5, self.bounds.origin.y + 0.5, self.bounds.width - 1, self.bounds.height - 1));
			
			backgroundGradient.draw(in: path, relativeCenterPosition: NSMakePoint(0, 0));
			strokeColor.setStroke();
			path.lineWidth = 0.5;
			path.stroke();
			
			if (self.isHighlighted) {
				NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0.2).setFill();
				path.fill();
			}
			
			// draw contents
			if (self.isMouseOver) {
				NSGraphicsContext.current?.shouldAntialias = true;

				path = NSBezierPath();
				
				if (type == NSWindow.ButtonType.zoomButton) {
					
					path.move(to: NSMakePoint(self.bounds.width / 2, self.bounds.height * 0.21));
					path.line(to: NSMakePoint(self.bounds.width / 2, self.bounds.height * 0.79));
					
					path.move(to: NSMakePoint(self.bounds.width * 0.79, self.bounds.height / 2));
					path.line(to: NSMakePoint(self.bounds.width * 0.21, self.bounds.height / 2));
					path.lineWidth = 1.25//0.75;
					
				} else if (type == NSWindow.ButtonType.miniaturizeButton) {
					
					path.move(to: NSMakePoint(self.bounds.width * 0.80, self.bounds.height / 2));
					path.line(to: NSMakePoint(self.bounds.width * 0.20, self.bounds.height / 2));
					path.lineWidth = 1.25//0.75;
					
				} else if (type == NSWindow.ButtonType.closeButton) {

					path.move(to: NSMakePoint(self.bounds.width * 0.27, self.bounds.height * 0.27));
					path.line(to: NSMakePoint(self.bounds.width * 0.73, self.bounds.height * 0.73));
					
					path.move(to: NSMakePoint(self.bounds.width * 0.73, self.bounds.height * 0.27));
					path.line(to: NSMakePoint(self.bounds.width * 0.27, self.bounds.height * 0.73));
					path.lineWidth = 1.25;
				}
				
				lineColor.setStroke();
				path.stroke();
			}
		}
		
		//	show our dirty mark (red dot)
		if (type == NSWindow.ButtonType.closeButton), let window = self.window, window.isDocumentEdited {
			let dotGradient = NSGradient(starting:NSColor.red, ending: NSColor.red)!;
			let pt = NSMakePoint(self.bounds.width * 0.42, self.bounds.height * 0.42)
			
			path.appendOval(in: NSMakeRect(pt.x, pt.y, 2.3, 2.3));
			dotGradient.draw(in: path, relativeCenterPosition: pt);
			NSColor.red.setStroke();
			path.lineWidth = 0.5;
			path.stroke();
		}
		
		if (self.isHighlighted) {
			NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0.2).setFill();
			path.fill();
		}
		NSGraphicsContext.current?.restoreGraphicsState();
	}
}

public class PanelButtonBar : NSView {
	private var _individualized:Bool = false;
	var individualized:Bool {
		set {
			self._individualized = newValue
			self.needsDisplay = true
		}
		get {
			return self._individualized;
		}
	}

	var closeButton : PanelButton?;
	var miniaturizeButton : PanelButton?;
	var zoomButton : PanelButton?;
	
	required public init?(coder: NSCoder) {
		super.init(coder: coder);
		self.setupViews(individualTrackingAreas: false);
	}
	
	override init (frame:NSRect) {
		super.init(frame: frame);
		self.setupViews(individualTrackingAreas: false);
	}
	
	func setupViews (individualTrackingAreas ita:Bool) {
		self.closeButton = PanelButton(frame: NSMakeRect(0, 0, 13, 13), type: NSWindow.ButtonType.closeButton, useTrackingArea: ita);
		self.miniaturizeButton = PanelButton(frame: NSMakeRect(20, 0, 13, 13), type: NSWindow.ButtonType.miniaturizeButton, useTrackingArea: ita);
		self.zoomButton = PanelButton(frame: NSMakeRect(40, 0, 13, 13), type: NSWindow.ButtonType.zoomButton, useTrackingArea: ita);
		
		self.addSubview(self.closeButton!);
		self.addSubview(self.miniaturizeButton!);
		self.addSubview(self.zoomButton!);
		
		let trackingArea = NSTrackingArea(rect: self.bounds, options: NSTrackingArea.Options.mouseEnteredAndExited.union(NSTrackingArea.Options.mouseMoved).union(NSTrackingArea.Options.activeAlways), owner: self, userInfo: nil);
		self.addTrackingArea(trackingArea)
		self.individualized = ita
	}
	
	override public func mouseEntered(with theEvent: NSEvent) {
		if !self.individualized {
			self.closeButton?.isMouseOver = true
			self.miniaturizeButton?.isMouseOver = true
			self.zoomButton?.isMouseOver = true
		}
	}
	
	override public func mouseExited(with theEvent: NSEvent) {
		self.closeButton?.isMouseOver = false
		self.miniaturizeButton?.isMouseOver = false
		self.zoomButton?.isMouseOver = false
	}
}
