#!/bin/bash

# Smart Notes Firebase Functions Validation Script

echo "🔍 Validating Firebase Functions setup..."

# Check if we're in the right directory
if [ ! -f "firebase.json" ]; then
    echo "❌ firebase.json not found. Please run this script from the project root."
    exit 1
fi

# Check if functions directory exists
if [ ! -d "functions" ]; then
    echo "❌ functions directory not found."
    exit 1
fi

# Check if package.json exists
if [ ! -f "functions/package.json" ]; then
    echo "❌ functions/package.json not found."
    exit 1
fi

# Check if dependencies are installed
if [ ! -d "functions/node_modules" ]; then
    echo "❌ Node modules not installed. Run 'npm install' in functions directory."
    exit 1
fi

# Check if TypeScript files exist
if [ ! -f "functions/src/index.ts" ]; then
    echo "❌ Main index.ts file not found."
    exit 1
fi

if [ ! -f "functions/src/summarization/summarizeNote.ts" ]; then
    echo "❌ summarizeNote.ts file not found."
    exit 1
fi

if [ ! -f "functions/src/services/openRouterService.ts" ]; then
    echo "❌ openRouterService.ts file not found."
    exit 1
fi

# Check if environment configuration exists
if [ ! -f "functions/.env" ]; then
    echo "⚠️  .env file not found. Copy from .env.example and configure."
fi

# Try to build the functions
echo "🔨 Testing build process..."
cd functions
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Check if compiled files exist
    if [ -f "lib/index.js" ]; then
        echo "✅ Main function compiled successfully"
    else
        echo "❌ Main function compilation failed"
        exit 1
    fi
    
    if [ -f "lib/summarization/summarizeNote.js" ]; then
        echo "✅ SummarizeNote function compiled successfully"
    else
        echo "❌ SummarizeNote function compilation failed"
        exit 1
    fi
    
    if [ -f "lib/services/openRouterService.js" ]; then
        echo "✅ OpenRouter service compiled successfully"
    else
        echo "❌ OpenRouter service compilation failed"
        exit 1
    fi
    
    echo ""
    echo "🎉 Firebase Functions setup validation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Configure your .env file with actual API keys"
    echo "2. Update .firebaserc with your Firebase project ID"
    echo "3. Test locally with: ./scripts/start-emulator.sh"
    echo "4. Deploy with: ./scripts/deploy-functions.sh"
    
else
    echo "❌ Build failed. Please check the error messages above."
    exit 1
fi