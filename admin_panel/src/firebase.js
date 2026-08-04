// firebase.js — Admin Panel Firebase Initialization
// Connects to the same Firebase project as the Flutter mobile app (cleanconnect-5a323)

import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "AIzaSyCiXCzwhOVG97hb2zyE6Xw5-gHh7UUI0uU",
  authDomain: "cleanconnect-5a323.firebaseapp.com",
  projectId: "cleanconnect-5a323",
  storageBucket: "cleanconnect-5a323.firebasestorage.app",
  messagingSenderId: "718487738924",
  appId: "1:718487738924:web:f81cdc6ef768fcec590f89",
};

const app = initializeApp(firebaseConfig);

export const db = getFirestore(app);
export const auth = getAuth(app);
export default app;
