# App Icon Export Instructions

## Quick Export Guide

This guide provides step-by-step instructions to convert the SVG icon design to the required PNG sizes for iOS.

## Prerequisites

Choose ONE of the following tools:

### Option A: ImageMagick (Recommended for macOS)
```bash
# Install via Homebrew
brew install imagemagick
```

### Option B: Inkscape (Free GUI Tool)
Download from: https://inkscape.org/

### Option C: Online Converter
Use: https://cloudconvert.com/svg-to-png (no installation needed)

### Option D: Adobe Illustrator / Figma (Professional)
Use your existing design software

---

## Method 1: ImageMagick (Command Line)

Navigate to the icon directory:
```bash
cd /Users/satoryouma/genie_0.1/LiveLingo/Resources/Assets.xcassets/AppIcon.appiconset/
```

Execute the following commands:

```bash
# Generate all required sizes
convert icon-design.svg -resize 1024x1024 -background none icon-1024.png
convert icon-design.svg -resize 180x180 -background none icon-180.png
convert icon-design.svg -resize 120x120 -background none icon-120.png
convert icon-design.svg -resize 167x167 -background none icon-167.png
convert icon-design.svg -resize 152x152 -background none icon-152.png

# Add corner radius (iOS requirement)
# Note: iOS automatically applies corner radius, but for preview:
convert icon-1024.png \
  \( +clone -alpha extract -draw 'fill black polygon 0,0 0,226 226,0 fill white circle 226,226 226,0' \
     \( +clone -flip \) -compose Multiply -composite \
     \( +clone -flop \) -compose Multiply -composite \
  \) -alpha off -compose CopyOpacity -composite icon-1024.png

# Verify files were created
ls -lh *.png
```

---

## Method 2: Inkscape (GUI)

1. Open Inkscape
2. File → Open → Select `icon-design.svg`
3. For each required size:
   - File → Export PNG Image
   - Set Width: 1024 (or other required size)
   - Set Height: 1024 (or other required size)
   - Filename: icon-1024.png (or appropriate name)
   - Click "Export"
4. Repeat for all sizes: 1024, 180, 120, 167, 152

---

## Method 3: Online Converter (No Installation)

1. Visit: https://cloudconvert.com/svg-to-png
2. Upload `icon-design.svg`
3. Click on wrench icon for settings:
   - Width: 1024 (adjust for each size)
   - Height: 1024
   - Quality: Best
4. Convert and download
5. Rename to `icon-1024.png`
6. Repeat for each size

---

## Method 4: Node.js Script (Automated)

Create a script to automate the process:

```bash
# Install sharp (image processing library)
npm install sharp

# Create export script
cat > export-icons.js << 'EOF'
const sharp = require('sharp');
const fs = require('fs');

const sizes = [
  { size: 1024, name: 'icon-1024.png' },
  { size: 180, name: 'icon-180.png' },
  { size: 120, name: 'icon-120.png' },
  { size: 167, name: 'icon-167.png' },
  { size: 152, name: 'icon-152.png' }
];

const svgPath = './icon-design.svg';
const outputDir = './';

async function exportIcons() {
  for (const { size, name } of sizes) {
    await sharp(svgPath)
      .resize(size, size)
      .png()
      .toFile(outputDir + name);
    console.log(`Generated: ${name} (${size}x${size})`);
  }
}

exportIcons().catch(err => console.error('Error:', err));
EOF

# Run the script
node export-icons.js
```

---

## Method 5: Python Script with Pillow

```python
# Install dependencies
pip3 install pillow cairosvg

# Create export script
cat > export_icons.py << 'EOF'
from cairosvg import svg2png
from PIL import Image
import io

sizes = [
    (1024, 'icon-1024.png'),
    (180, 'icon-180.png'),
    (120, 'icon-120.png'),
    (167, 'icon-167.png'),
    (152, 'icon-152.png')
]

svg_file = 'icon-design.svg'

for size, filename in sizes:
    # Convert SVG to PNG
    png_bytes = svg2png(
        url=svg_file,
        output_width=size,
        output_height=size
    )

    # Save PNG
    with open(filename, 'wb') as f:
        f.write(png_bytes)

    print(f'Generated: {filename} ({size}x{size})')

print('All icons exported successfully!')
EOF

# Run the script
python3 export_icons.py
```

---

## Verification Checklist

After exporting, verify:

- [ ] All 5 PNG files exist in the appiconset directory
- [ ] File sizes are reasonable (typically 50-500KB each)
- [ ] Icons appear sharp when viewed at actual size
- [ ] Colors match the design specification
- [ ] No transparency issues (background should be opaque)

### Verify with command:
```bash
# Check file existence and sizes
ls -lh /Users/satoryouma/genie_0.1/LiveLingo/Resources/Assets.xcassets/AppIcon.appiconset/*.png

# Check image dimensions
for file in *.png; do
  echo "$file:"
  sips -g pixelWidth -g pixelHeight "$file"
done
```

---

## Integration with Xcode

1. Open your Xcode project
2. Navigate to Assets.xcassets
3. Select AppIcon
4. Drag and drop each PNG into the appropriate slot:
   - 1024x1024 → App Store iOS
   - 180x180 → iPhone 60x60 @3x
   - 120x120 → iPhone 60x60 @2x
   - 167x167 → iPad Pro 83.5x83.5 @2x
   - 152x152 → iPad 76x76 @2x

5. Build and run to test on simulator/device

---

## Troubleshooting

### Issue: SVG doesn't render correctly
**Solution**: Check if your SVG tool supports gradients and animations. Try removing `<animate>` tags for static export.

### Issue: Colors look different
**Solution**: Ensure export uses sRGB color space. Check your tool's export settings.

### Issue: Icon appears blurry
**Solution**: Verify you're exporting at exact pixel dimensions (no scaling after export).

### Issue: ImageMagick not found
**Solution**: Install via Homebrew: `brew install imagemagick`

### Issue: Corner radius not applied
**Solution**: iOS applies corner radius automatically. Don't worry if exported PNGs have square corners.

---

## Quick Test in Xcode

After exporting and integrating:

1. Product → Clean Build Folder (Shift+Cmd+K)
2. Product → Build (Cmd+B)
3. Run on Simulator (Cmd+R)
4. Check icon on home screen
5. Verify in App Switcher
6. Test on actual device if possible

---

## Support

If you encounter issues:
1. Check that SVG is valid (open in browser)
2. Verify tool installation
3. Try alternative export method
4. Check Xcode's asset catalog for errors

For design changes, edit `icon-design.svg` and re-export all sizes to maintain consistency.
