# Smart Notes Firebase Functions

This directory contains the Firebase Functions for the Smart Notes AI Summarization feature.

## Setup

1. **Install Dependencies**
   ```bash
   cd functions
   npm install
   ```

2. **Environment Configuration**
   - Copy `.env.example` to `.env`
   - Update the `OPENROUTER_API_KEY` with your actual API key
   - Update the `FIREBASE_PROJECT_ID` with your Firebase project ID

3. **Build the Functions**
   ```bash
   npm run build
   ```

4. **Run Locally (Emulator)**
   ```bash
   npm run serve
   ```

5. **Deploy to Firebase**
   ```bash
   npm run deploy
   ```

## Functions

### summarizeNoteFunction
- **Type**: HTTPS Callable Function
- **Purpose**: Generates AI-powered summaries for note content
- **Authentication**: Required (Firebase Auth)
- **Rate Limiting**: Implemented per user
- **Models**: OpenAI GPT-3.5-turbo (primary), Claude-3-Haiku (fallback)

#### Request Format
```typescript
{
  noteId: string;
  content: string;
  userId: string;
}
```

#### Response Format
```typescript
{
  success: boolean;
  summary?: string;
  error?: string;
}
```

## Environment Variables

- `OPENROUTER_API_KEY`: API key for OpenRouter service
- `FIREBASE_PROJECT_ID`: Firebase project identifier

## Security Features

- User authentication validation
- Note ownership verification
- Content length validation (100-10,000 characters)
- API key protection (server-side only)
- Rate limiting and quota management

## Error Handling

- Network timeouts (30 seconds)
- API rate limiting with exponential backoff
- Model fallback (GPT-3.5 → Claude-3-Haiku)
- Comprehensive error logging