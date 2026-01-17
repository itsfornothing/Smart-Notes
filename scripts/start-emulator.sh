#!/bin/bash

# Smart Notes Firebase Emulator Start Script

echo "🔧 Starting Firebase Emulator Suite..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "firebase.json" ]; then
    echo "❌ firebase.json not found. Please run this script from the project root."
    exit 1
fi

# Navigate to functions directory and install dependencies if needed
if [ ! -d "functions/node_modules" ]; then
    echo "📦 Installing function dependencies..."
    cd functions
    npm install
    cd ..
fi

# Build the functions
echo "🔨 Building functions..."
cd functions
npm run build
cd ..

# Start the emulator
echo "🚀 Starting Firebase Emulator Suite..."
echo "📱 Functions will be available at: http://localhost:5001"
echo "🗄️  Firestore will be available at: http://localhost:8080"
echo "📊 Emulator UI will be available at: http://localhost:4000"
echo ""
echo "Press Ctrl+C to stop the emulator"

firebase emulators:start