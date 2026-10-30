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

  const { token, title, body, data } = req.body || {};

  if (!token) {
    return res.status(400).json({ error: 'FCM token is required' });
  }

  const message = {
    token: token,
    notification: {
      title: title || '📞 Acadeno CRM',
      body: body || 'You have new leads assigned'
    },
    data: {
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      type: String(data?.type || 'lead_assigned'),
      dateKey: String(data?.dateKey || ''),
      tabIndex: String(data?.tabIndex || '0'),
      leadCount: String(data?.leadCount || '1')
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'acadeno_crm_high_importance',
        sound: 'default',
        priority: 'high',
        defaultSound: true,
        defaultVibrateTimings: true
      }
    },
    webpush: {
      headers: {
        Urgency: 'high'
      },
      notification: {
        title: title || '📞 Acadeno CRM',
        body: body || 'You have new leads assigned',
        icon: '/icons/Icon-192.png'
      }
    }
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Push sent successfully:', response);
    return res.status(200).json({ success: true, messageId: response });
  } catch (error) {
    console.error('Error sending FCM push:', error);
    return res.status(500).json({ error: error.message || 'Failed to dispatch push notification' });
  }
};
