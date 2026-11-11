const admin = require('firebase-admin');

// Initialize Firebase Admin with Service Account from Environment Variables
if (!admin.apps.length) {
  try {
    const serviceAccountKey = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (serviceAccountKey) {
      const credentials = JSON.parse(serviceAccountKey);
      admin.initializeApp({
        credential: admin.credential.cert(credentials),
        projectId: credentials.project_id || 'acadenocrm-b727a'
      });
    } else {
      admin.initializeApp({
        projectId: 'acadenocrm-b727a'
      });
    }
  } catch (e) {
    console.error('Firebase Admin initialization error:', e);
  }
}

module.exports = async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { email, uid, newPassword } = req.body || {};

  if (!email && !uid) {
    return res.status(400).json({ error: 'email or uid is required' });
  }

  const cleanEmail = email ? String(email).trim().toLowerCase() : null;

  try {
    let userRecord = null;
    if (uid) {
      try {
        userRecord = await admin.auth().getUser(String(uid).trim());
      } catch (_) {}
    }
    if (!userRecord && cleanEmail) {
      try {
        userRecord = await admin.auth().getUserByEmail(cleanEmail);
      } catch (_) {}
    }

    // Direct password update
    if (newPassword && String(newPassword).length >= 6) {
      if (!userRecord) {
        if (cleanEmail) {
          userRecord = await admin.auth().createUser({
            uid: uid ? String(uid).trim() : undefined,
            email: cleanEmail,
            password: String(newPassword),
            emailVerified: true
          });
          return res.status(200).json({
            success: true,
            userCreated: true,
            passwordUpdated: true,
            email: cleanEmail
          });
        } else {
          return res.status(404).json({
            error: 'User not found in Firebase Authentication'
          });
        }
      }

      await admin.auth().updateUser(userRecord.uid, {
        password: String(newPassword)
      });

      return res.status(200).json({
        success: true,
        passwordUpdated: true,
        email: userRecord.email
      });
    }

    // Generate direct password reset link
    if (!userRecord && cleanEmail) {
      return res.status(404).json({
        error: `No Firebase Authentication user found for '${cleanEmail}'. Please verify the email address or use 'Set Password Directly' to provision their credentials.`
      });
    }

    const targetEmail = userRecord ? userRecord.email : cleanEmail;
    const link = await admin.auth().generatePasswordResetLink(targetEmail);

    return res.status(200).json({
      success: true,
      link: link,
      email: targetEmail
    });
  } catch (error) {
    console.error('Password reset handler error:', error);
    return res.status(500).json({
      error: error.message || 'Failed to process password reset'
    });
  }
};

