import * as admin from 'firebase-admin';
import { summarizeNote } from './summarization/summarizeNote';

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export the summarizeNote function
export const summarizeNoteFunction = summarizeNote;