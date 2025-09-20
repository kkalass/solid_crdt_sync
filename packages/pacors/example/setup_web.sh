#!/bin/bash

# Web Setup Script for Personal Notes App
# Downloads SQLite WASM files required for pacors_drift on web

set -e  # Exit on any error

echo "🌐 Setting up web dependencies for Personal Notes App..."
echo ""

# Check if we're in the right directory
if [[ ! -f "pubspec.yaml" ]] || ! grep -q "personal_notes_app" pubspec.yaml; then
    echo "❌ Error: Run this script from the packages/pacors/example directory"
    echo "   Current directory: $(pwd)"
    exit 1
fi

# Create web directory if it doesn't exist
if [[ ! -d "web" ]]; then
    echo "❌ Error: web/ directory not found. Did you run 'flutter create' to generate platform files?"
    echo "   Run: flutter create --platforms=web ."
    exit 1
fi

cd web

echo "📥 Downloading SQLite3 WASM file..."
if curl -f -L -o sqlite3.wasm "https://github.com/simolus3/sqlite3.dart/releases/latest/download/sqlite3.wasm"; then
    echo "✅ Downloaded sqlite3.wasm ($(du -h sqlite3.wasm | cut -f1))"
else
    echo "❌ Failed to download sqlite3.wasm"
    echo "   Manual download: https://github.com/simolus3/sqlite3.dart/releases/latest"
    exit 1
fi

echo "📥 Downloading Drift worker file..."
if curl -f -L -o drift_worker.js "https://github.com/simolus3/drift/releases/latest/download/drift_worker.js"; then
    echo "✅ Downloaded drift_worker.js ($(du -h drift_worker.js | cut -f1))"
else
    echo "❌ Failed to download drift_worker.js"
    echo "   Manual download: https://github.com/simolus3/drift/releases/latest"
    exit 1
fi

cd ..

echo ""
echo "🎉 Web setup complete!"
echo ""
echo "Next steps:"
echo "  1. flutter pub get"
echo "  2. dart run build_runner build"
echo "  3. flutter run -d chrome"
echo ""
echo "ℹ️  Note: These files are only needed for the pacors_drift storage backend."
echo "   The core pacors library works with any storage implementation."