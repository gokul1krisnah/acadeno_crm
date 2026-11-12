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

  const { confirmationKey } = req.body || {};
  if (confirmationKey !== 'ACADENO_PURGE_FRESH_CRM_CONFIRMED') {
    return res.status(400).json({
      error: 'Invalid or missing confirmationKey. Must be ACADENO_PURGE_FRESH_CRM_CONFIRMED.'
    });
  }

  try {
    const db = admin.firestore();
    const collectionsToPurge = [
      'leads',
      'campaigns',
      'lead_assignments',
      'assignments',
      'college_visits',
      'call_logs',
      'lead_phones',
      'alerts',
      'notification_queue',
      'colleges'
    ];

    let totalDeleted = 0;
    const summary = {};

    for (const colName of collectionsToPurge) {
      const snapshot = await db.collection(colName).get();
      if (snapshot.empty) {
        summary[colName] = 0;
        continue;
      }

      let count = 0;
      let batch = db.batch();

      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
        count++;
        totalDeleted++;

        if (count % 400 === 0) {
          await batch.commit();
          batch = db.batch();
        }
      }

      if (count % 400 !== 0) {
        await batch.commit();
      }

      summary[colName] = count;
    }

    return res.status(200).json({
      success: true,
      message: 'CRM Database successfully purged while strictly preserving users collection.',
      totalDeleted,
      summary
    });
  } catch (error) {
    console.error('Error during CRM database purge:', error);
    return res.status(500).json({
      error: error.message || 'Internal Server Error'
    });
  }
};

