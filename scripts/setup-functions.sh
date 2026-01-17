#!/bin/bash

# Smart Notes Firebase Functions Setup Script

echo "🔧 Setting up Firebase Functions for Smart Notes..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18 or later."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js version 18 or later is required. Current version: $(node -v)"
    exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "📦 Installing Firebase CLI..."
    npm install -g firebase-tools
fi

# Navigate to functions directory
cd functions

# Install dependencies
echo "📦 Installing function dependencies..."
npm install

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please update the .env file with your actual API keys and project ID"
fi

# Build the functions
echo "🔨 Building functions..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Firebase Functions setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Update functions/.env with your actual API keys"
    echo "2. Update .firebaserc with your Firebase project ID"
    echo "3. Run 'npm run serve' in the functions directory to start the emulator"
    echo "4. Run 'npm run deploy' in the functions directory to deploy to Firebase"
else
    echo "❌ Build failed. Please check the error messages above."
    exit 1
fi