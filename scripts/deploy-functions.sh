#!/bin/bash

# Smart Notes Firebase Functions Deployment Script

echo "🚀 Starting Firebase Functions deployment..."

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

# Navigate to functions directory and install dependencies
echo "📦 Installing function dependencies..."
cd functions
npm install

# Build the functions
echo "🔨 Building functions..."
npm run build

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "❌ Build failed. Please fix the errors and try again."
    exit 1
fi

# Go back to project root
cd ..

# Deploy functions
echo "🚀 Deploying functions to Firebase..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo "✅ Functions deployed successfully!"
    echo "🔗 You can view your functions in the Firebase Console"
else
    echo "❌ Deployment failed. Please check the error messages above."
    exit 1
fi