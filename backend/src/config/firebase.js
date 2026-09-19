// backend/src/config/firebase.js
const admin = require('firebase-admin');

// TODO: Replace with your actual serviceAccountKey.json or set FIREBASE_SERVICE_ACCOUNT env variable
let serviceAccount;
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } else {
    serviceAccount = require('../../firebase-service-account.json');
  }
} catch {
  console.warn('⚠️  Firebase service account not found — auth middleware will be disabled in dev mode.');
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: serviceAccount
      ? admin.credential.cert(serviceAccount)
      : admin.credential.applicationDefault(),
  });
}

module.exports = admin;
