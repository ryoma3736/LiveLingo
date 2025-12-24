#!/usr/bin/env node

/**
 * LiveLingo App Icon Export Script
 *
 * This script converts SVG icon designs to PNG files at required iOS sizes.
 *
 * Requirements:
 *   npm install sharp
 *
 * Usage:
 *   node export-icons.js
 *   or
 *   npm run export-icons
 */

const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

// Icon configurations
const iconVariants = [
  {
    svg: 'icon-design.svg',
    outputs: [
      { size: 1024, filename: 'icon-1024.png' }
    ]
  },
  {
    svg: 'icon-design-dark.svg',
    outputs: [
      { size: 1024, filename: 'icon-1024-dark.png' }
    ]
  },
  {
    svg: 'icon-design-tinted.svg',
    outputs: [
      { size: 1024, filename: 'icon-1024-tinted.png' }
    ]
  }
];

// Additional sizes (if needed for older iOS versions)
const additionalSizes = [
  { size: 180, filename: 'icon-180.png' },
  { size: 120, filename: 'icon-120.png' },
  { size: 167, filename: 'icon-167.png' },
  { size: 152, filename: 'icon-152.png' }
];

const currentDir = __dirname;

/**
 * Export a single icon
 */
async function exportIcon(svgPath, outputPath, size) {
  try {
    await sharp(svgPath)
      .resize(size, size, {
        fit: 'contain',
        background: { r: 0, g: 0, b: 0, alpha: 0 }
      })
      .png({
        quality: 100,
        compressionLevel: 9
      })
      .toFile(outputPath);

    const stats = fs.statSync(outputPath);
    console.log(`✅ Generated: ${path.basename(outputPath)} (${size}x${size}, ${(stats.size / 1024).toFixed(1)}KB)`);
  } catch (error) {
    console.error(`❌ Error generating ${outputPath}:`, error.message);
    throw error;
  }
}

/**
 * Verify generated icon
 */
async function verifyIcon(filePath) {
  try {
    const metadata = await sharp(filePath).metadata();
    return {
      width: metadata.width,
      height: metadata.height,
      format: metadata.format,
      size: fs.statSync(filePath).size
    };
  } catch (error) {
    console.error(`❌ Error verifying ${filePath}:`, error.message);
    return null;
  }
}

/**
 * Main export function
 */
async function exportAllIcons() {
  console.log('🎨 LiveLingo App Icon Export\n');
  console.log('Starting icon generation...\n');

  let successCount = 0;
  let failCount = 0;

  // Export all variants
  for (const variant of iconVariants) {
    const svgPath = path.join(currentDir, variant.svg);

    if (!fs.existsSync(svgPath)) {
      console.error(`❌ SVG file not found: ${variant.svg}`);
      failCount++;
      continue;
    }

    for (const output of variant.outputs) {
      const outputPath = path.join(currentDir, output.filename);

      try {
        await exportIcon(svgPath, outputPath, output.size);
        successCount++;
      } catch (error) {
        failCount++;
      }
    }
  }

  // Export additional sizes from the main icon
  const mainSvg = path.join(currentDir, 'icon-design.svg');
  if (fs.existsSync(mainSvg)) {
    console.log('\n📦 Generating additional sizes (optional)...\n');

    for (const { size, filename } of additionalSizes) {
      const outputPath = path.join(currentDir, filename);

      try {
        await exportIcon(mainSvg, outputPath, size);
        successCount++;
      } catch (error) {
        failCount++;
      }
    }
  }

  // Verification
  console.log('\n🔍 Verifying generated icons...\n');

  const allFiles = [
    ...iconVariants.flatMap(v => v.outputs.map(o => o.filename)),
    ...additionalSizes.map(s => s.filename)
  ];

  for (const filename of allFiles) {
    const filePath = path.join(currentDir, filename);

    if (!fs.existsSync(filePath)) {
      continue;
    }

    const info = await verifyIcon(filePath);
    if (info) {
      console.log(`✅ ${filename}: ${info.width}x${info.height} ${info.format.toUpperCase()} (${(info.size / 1024).toFixed(1)}KB)`);
    }
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log(`✅ Successfully generated: ${successCount} icons`);
  if (failCount > 0) {
    console.log(`❌ Failed: ${failCount} icons`);
  }
  console.log('='.repeat(60));

  console.log('\n📱 Next steps:');
  console.log('1. Open your Xcode project');
  console.log('2. Navigate to Assets.xcassets → AppIcon');
  console.log('3. Verify that icons appear correctly');
  console.log('4. Build and test on simulator/device\n');

  return failCount === 0;
}

// Run if called directly
if (require.main === module) {
  exportAllIcons()
    .then(success => {
      process.exit(success ? 0 : 1);
    })
    .catch(error => {
      console.error('\n❌ Fatal error:', error);
      process.exit(1);
    });
}

module.exports = { exportAllIcons, exportIcon, verifyIcon };
