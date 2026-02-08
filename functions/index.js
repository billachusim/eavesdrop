const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {RtcTokenBuilder, RtcRole} = require("agora-token");

admin.initializeApp();

// Your Agora credentials
const APP_ID = "7cbfdc57592f47b2a939e2838238f066";
const APP_CERTIFICATE = "9bca5f09b5ab41bfbb09b15230835f90";

exports.generateAgoraToken = onCall(async (request) => {
  // Authentication check
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }

  const channelName = request.data.channelName;
  if (!channelName || typeof channelName !== "string") {
    throw new HttpsError(
        "invalid-argument",
        'The function must be called with "channelName".',
    );
  }

  const uid = request.data.uid && typeof request.data.uid === "number" ? request.data.uid : 0;
  const role = RtcRole.PUBLISHER;
  const expirationTimeInSeconds = 3600; // 1 hour
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  try {
    console.log(`Generating token for channel: "${channelName}" with UID: ${uid}`);

    const token = RtcTokenBuilder.buildTokenWithUid(
        APP_ID,
        APP_CERTIFICATE,
        channelName,
        uid,
        role,
        privilegeExpiredTs,
    );

    console.log(`Successfully generated token: ${token}`);
    return {token: token};
  } catch (error) {
    console.error("Error generating Agora token:", error);
    throw new HttpsError(
        "internal",
        "Failed to generate Agora token.",
    );
  }
});

exports.scheduledCallHandler = onSchedule("every 1 minutes", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const callsRef = admin.firestore().collection("calls");

  // Get all calls that are not live and are scheduled to start
  const query = callsRef
      .where("isLive", "==", false)
      .where("hasEnded", "==", false)
      .where("startTime", "<=", now);

  const snapshot = await query.get();

  if (snapshot.empty) {
    console.log("No scheduled calls to start.");
    return null;
  }

  for (const doc of snapshot.docs) {
    const call = doc.data();
    const callId = doc.id;

    // Set the call to live
    await doc.ref.update({isLive: true});

    // Get all users who have set a reminder
    const remindersSnapshot = await doc.ref.collection("reminders").get();
    const userIds = remindersSnapshot.docs.map((d) => d.id);

    // Also notify the host
    userIds.push(call.hostId);

    // Get the FCM tokens for these users
    const tokens = [];
    for (const userId of userIds) {
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (userDoc.exists) {
        const user = userDoc.data();
        if (user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      }
    }

    // Send a notification to each user
    if (tokens.length > 0) {
      const message = {
        notification: {
          title: "Call Starting!",
          body: `The call "${call.title}" is starting now!`,
        },
        data: {
          callId: callId,
        },
        tokens: tokens,
      };

      try {
        await admin.messaging().sendMulticast(message);
        console.log(`Notifications sent for call ${callId}`);
      } catch (error) {
        console.error(`Error sending notifications for call ${callId}:`, error);
      }
    }
  }

  return null;
});
