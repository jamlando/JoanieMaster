#!/usr/bin/env python3
"""
Create a simple app icon for Joanie
"""
import os
import subprocess

def create_app_icon():
    """Create a simple app icon for Joanie"""
    
    # Create SVG content for the icon
    svg_content = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
    <defs>
        <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#FF6B9D;stop-opacity:1" />
            <stop offset="50%" style="stop-color:#C4E8C7;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#FFD93D;stop-opacity:1" />
        </linearGradient>
    </defs>
    <rect width="1024" height="1024" rx="180" ry="180" fill="url(#grad1)"/>
    
    <!-- Art palette icon -->
    <circle cx="512" cy="400" r="80" fill="white" opacity="0.9"/>
    <circle cx="480" cy="380" r="25" fill="#FF6B9D"/>
    <circle cx="544" cy="380" r="25" fill="#C4E8C7"/>
    <circle cx="512" cy="420" r="25" fill="#FFD93D"/>
    
    <!-- Brush -->
    <rect x="620" y="350" width="8" height="60" fill="#8B4513" rx="4"/>
    <path d="M624 350 Q628 340 632 350 Q628 360 624 350" fill="#FF6B9D"/>
    
    <!-- Stars around -->
    <g fill="white" opacity="0.8">
        <polygon points="200,200 210,230 240,230 215,245 225,275 200,260 175,275 185,245 160,230 190,230" />
        <polygon points="800,180 810,210 840,210 815,225 825,255 800,240 775,255 785,225 760,210 790,210" />
        <polygon points="180,800 190,830 220,830 195,845 205,875 180,860 155,875 165,845 140,830 170,830" />
        <polygon points="850,750 860,780 890,780 865,795 875,825 850,810 825,825 835,795 810,780 840,780" />
    </g>
    
    <!-- App name -->
    <text x="512" y="600" font-family="Arial, sans-serif" font-size="120" font-weight="bold" 
          text-anchor="middle" fill="white">Joanie</text>
    
    <!-- Subtitle -->
    <text x="512" y="680" font-family="Arial, sans-serif" font-size="40" 
          text-anchor="middle" fill="white" opacity="0.9">Artwork</text>
</svg>'''
    
    # Write SVG file
    with open('/tmp/joanie_icon.svg', 'w') as f:
        f.write(svg_content)
    
    print("Created SVG icon at /tmp/joanie_icon.svg")
    print("SVG content created successfully!")
    print("\nTo create PNG from SVG, you can use:")
    print("1. Online converter (recommended for this step)")
    print("2. Install ImageMagick: brew install imagemagick")
    print("3. Then run: convert /tmp/joanie_icon.svg /tmp/joanie_icon.png")
    
    return True

if __name__ == "__main__":
    create_app_icon()
