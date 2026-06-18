#!/bin/bash
set -e

PROJECT_DIR="/home/toms/projects/Gem"
cd "$PROJECT_DIR"

echo "=== Gem (Flutter Edition) Setup ==="

# Clean build artifacts and reset CMake cache to prevent /usr/local permission errors
echo "Cleaning old build files and resetting CMake cache..."
/home/toms/flutter/bin/flutter clean

# 1. Compile the app for Linux in Release mode
echo "Compiling Flutter application for Linux (Release)..."
/home/toms/flutter/bin/flutter build linux --release

# 2. Create the run.sh script to execute the release binary
echo "Creating run.sh..."
cat << EOF > "$PROJECT_DIR/run.sh"
#!/bin/bash
cd "$PROJECT_DIR"
./build/linux/x64/release/bundle/gem
EOF
chmod +x "$PROJECT_DIR/run.sh"

# 3. Create the gem.desktop launcher
echo "Creating gem.desktop..."
cat << EOF > "$PROJECT_DIR/gem.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Gem
Comment=Google Gemini Desktop (Flutter Edition)
Exec="$PROJECT_DIR/run.sh"
Icon=gem
Terminal=false
Categories=Network;WebBrowser;Office;
StartupWMClass=com.google.gemini
EOF
chmod +x "$PROJECT_DIR/gem.desktop"

# 4. Copy to desktop applications and register icon
echo "Registering application icon and entry with Desktop environment..."
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.local/share/icons"
cp "$PROJECT_DIR/assets/icon.png" "$HOME/.local/share/icons/gem.png"
cp "$PROJECT_DIR/gem.desktop" "$HOME/.local/share/applications/gem.desktop"

# 5. Refresh desktop and icon cache
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache "$HOME/.local/share/icons" 2>/dev/null || true

echo "=== Setup Complete! ==="
echo "You can now search for 'Gem' in your application menu or run: ./run.sh"
