#!/bin/bash
set -e

echo "=== Setting up Flutter SDK for Vercel Deployment ==="
if [ ! -d "$HOME/flutter" ]; then
  echo "Cloning Flutter stable SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
else
  echo "Reusing cached Flutter SDK..."
fi

export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter config --enable-web

echo "=== Cleaning previous build artifacts ==="
flutter clean

echo "=== Resolving dependencies ==="
flutter pub get

echo "=== Compiling Flutter Web Release ==="
flutter build web --release --no-tree-shake-icons

echo "=== Flutter Web Release Build Complete ==="
