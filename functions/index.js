const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Helper: Send FCM Push Notification to a user by UID.
 */
async function sendPushToUser(uid, title, body, data = {}) {
  try {
    if (!uid) return;
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data() || {};
    const fcmToken = userData.fcmToken;
    if (!fcmToken) {
      console.log(`[Push] User ${uid} has no FCM token registered.`);
      return;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "acadeno_crm_notifications",
          sound: "default",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(`[Push] Sent notification to ${uid} (${response})`);
    return response;
  } catch (error) {
    console.error(`[Push Error] Failed to send push to ${uid}:`, error);
  }
}

/**
 * TRIGGER 1: Real-time Lead Assignment Notification
 * Fires immediately when an Admin assigns a lead to an executive.
 */
exports.onLeadAssigned = onDocumentCreated("assignments/{assignmentId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data();
  const executiveUid = data.executiveUid;
  const leadName = data.leadName || "Student";
  const collegeBranch = data.collegeBranch || "College inquiry";
  const assignedByName = data.assignedByName || "Admin";

  const title = "📞 New Lead Assigned";
  const body = `${leadName} (${collegeBranch}) has been assigned to you by ${assignedByName}.`;

  await sendPushToUser(executiveUid, title, body, {
    leadId: data.leadId || "",
    tabIndex: "0",
    type: "lead_assigned",
  });
});

/**
 * TRIGGER 2: Batch Assignment Notification (from Leads & Assign or Campaign Split)
 * Fires when an audit log entry for lead assignment is created.
 */
exports.onBatchAssignmentAudit = onDocumentCreated("audit_log/{auditId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data();
  if (data.category !== "assignment" && data.category !== "campaign_assignment") {
    return;
  }

  // If this audit was targeted to a specific executive or multiple executives
  console.log(`[Audit Assignment] ${data.action} - Target: ${data.target}`);
});

/**
 * TRIGGER 3: Daily 9:00 AM Morning Staff Briefing (Cron)
 * Runs at 9:00 AM IST (Asia/Kolkata) every morning.
 * Sends personalized notification: "Good morning [Name]! X calls assigned · Y follow-ups · Z overdue."
 */
exports.morningStaffBriefing = onSchedule(
  {
    schedule: "0 9 * * *",
    timeZone: "Asia/Kolkata",
  },
  async (event) => {
    console.log("[Morning Briefing] Starting 9:00 AM scheduled briefing...");

    const now = new Date();
    // YYYY-MM-DD in IST
    const istDate = new Date(now.toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
    const dateKey = `${istDate.getFullYear()}-${String(istDate.getMonth() + 1).padStart(2, "0")}-${String(istDate.getDate()).padStart(2, "0")}`;

    // Get all active staff users
    const usersSnap = await db.collection("users").where("isActive", "==", true).get();

    for (const userDoc of usersSnap.docs) {
      const uData = userDoc.data();
      const uid = userDoc.id;
      const name = (uData.name || "Executive").split(" ")[0]; // First name
      const fcmToken = uData.fcmToken;

      if (!fcmToken) continue;

      // Count today's assignments
      const assignSnap = await db
        .collection("assignments")
        .where("executiveUid", "==", uid)
        .where("dateKey", "==", dateKey)
        .get();
      const assignedCount = assignSnap.docs.length;

      // Count pending follow-ups
      const leadsSnap = await db
        .collection("leads")
        .where("assignedToUid", "==", uid)
        .where("isDone", "==", false)
        .get();

      let followUpToday = 0;
      let overdueCount = 0;

      for (const lDoc of leadsSnap.docs) {
        const lData = lDoc.data();
        const status = (lData.status || "").toLowerCase();
        const followUpTime = (lData.followUpTime || "").toLowerCase();
        if (followUpTime.includes("yesterday") || status === "overdue") {
          overdueCount++;
        } else if (status === "follow-up" || status === "callback" || status === "interested") {
          followUpToday++;
        }
      }

      const title = `☀️ Good morning, ${name}!`;
      const overdueSnippet = overdueCount > 0 ? ` · ${overdueCount} overdue` : "";
      const body = `${assignedCount} calls assigned · ${followUpToday} follow-ups today${overdueSnippet}. Open your call sheet.`;

      await sendPushToUser(uid, title, body, {
        tabIndex: "0",
        type: "morning_briefing",
      });
    }

    console.log("[Morning Briefing] Completed.");
  }
);

/**
 * TRIGGER 4: Outgoing Notification Queue
 * Allows Flutter client (e.g. Admin Dashboard) to request an immediate push notification
 * by creating a document in `notification_queue/{id}`.
 */
exports.processNotificationQueue = onDocumentCreated("notification_queue/{queueId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data();
  const recipientUid = data.recipientUid;
  const title = data.title || "ACADENO CRM";
  const body = data.body || "";
  const payloadData = data.data || {};

  if (recipientUid === "all") {
    // Broadcast to all active users
    const usersSnap = await db.collection("users").where("isActive", "==", true).get();
    for (const doc of usersSnap.docs) {
      await sendPushToUser(doc.id, title, body, payloadData);
    }
  } else if (recipientUid) {
    await sendPushToUser(recipientUid, title, body, payloadData);
  }

  await snap.ref.update({
    status: "delivered",
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

