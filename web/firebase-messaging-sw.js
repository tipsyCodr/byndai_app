// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
    apiKey: "AIzaSyCQDtbMJtc7nD-my79VeZKViVxyUjhyQ24",
    authDomain: "byndai.firebaseapp.com",
    projectId: "byndai",
    storageBucket: "byndai.firebasestorage.app",
    messagingSenderId: "649165501928",
    appId: "1:649165501928:web:94dda1324544ed1677205d",
    measurementId: "G-XY16CSBD8E"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);