// Firebase Configuration & Service Initializer
import { initializeApp } from 'firebase/app';
import { getAuth, onAuthStateChanged, signInWithEmailAndPassword, createUserWithEmailAndPassword, signInWithCustomToken, signOut, updateProfile, getIdTokenResult } from 'firebase/auth';
import { 
  getFirestore, 
  collection, 
  doc, 
  getDoc, 
  getDocs, 
  setDoc, 
  updateDoc, 
  deleteDoc, 
  addDoc, 
  query, 
  where, 
  orderBy, 
  limit, 
  onSnapshot, 
  serverTimestamp, 
  arrayUnion,
  increment
} from 'firebase/firestore';
import { getStorage, ref, uploadString, getDownloadURL } from 'firebase/storage';

export const firebaseConfig = {
  apiKey: "AIzaSyDVaNNyALnsrqrqTj371nGn8gbeBWL7fGc",
  authDomain: "dessert-institute.firebaseapp.com",
  projectId: "dessert-institute",
  storageBucket: "dessert-institute.firebasestorage.app",
  messagingSenderId: "400647872169",
  appId: "1:400647872169:web:fae72682b4da8841ec93b8"
};

// Initialize Core Firebase Services
export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Export Firestore Helpers
export { 
  collection, 
  doc, 
  getDoc, 
  getDocs, 
  setDoc, 
  updateDoc, 
  deleteDoc, 
  addDoc, 
  query, 
  where, 
  orderBy, 
  limit, 
  onSnapshot, 
  serverTimestamp, 
  arrayUnion,
  increment,
  ref,
  uploadString,
  getDownloadURL,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithCustomToken,
  signOut,
  updateProfile,
  getIdTokenResult
};
