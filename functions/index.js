const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {RtcTokenBuilder, RtcRole} = require("agora-token");

admin.initializeApp();

const APP_ID = "7cbfdc57592f47b2a939e2838238f066";
const APP_CERTIFICATE = "9bca5f09b5ab41bfbb09b15230835f90";

const TOPIC_KEYWORDS = {
  relationships: ["relationship", "relationships", "partner", "marriage", "romance"],
  career: ["career", "job", "work", "interview", "promotion"],
  anxiety: ["anxiety", "panic", "worry", "fear"],
  loneliness: ["lonely", "loneliness", "alone", "isolated"],
  family: ["family", "parent", "mom", "dad", "sibling"],
  "self-esteem": ["self-esteem", "confidence", "insecure"],
  friendship: ["friend", "friendship"],
  breakups: ["breakup", "breakups", "heartbreak"],
  parenting: ["parenting", "child", "kids", "motherhood", "fatherhood"],
  grief: ["grief", "loss", "mourning"],
  stress: ["stress", "pressured", "tension"],
  burnout: ["burnout", "burned out", "exhausted"],
  money: ["money", "finance", "debt", "salary"],
  faith: ["faith", "spiritual", "religion"],
  identity: ["identity", "self", "belonging"],
  health: ["health", "wellness", "sick", "illness"],
  habits: ["habit", "routine", "discipline"],
  motivation: ["motivation", "focus", "goals"],
  boundaries: ["boundary", "boundaries"],
  dating: ["dating", "date", "crush", "situationship"],
};

function chunkArray(array, size) {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}

function extractCallTopics(call) {
  const topics = new Set();

  if (Array.isArray(call.topics)) {
    call.topics.forEach((topic) => topics.add(String(topic).toLowerCase()));
  }

  if (call.userMood) {
    topics.add(String(call.userMood).toLowerCase());
  }

  const haystack = `${call.title || ""} ${call.userMood || ""}`.toLowerCase();
  Object.entries(TOPIC_KEYWORDS).forEach(([topic, keywords]) => {
    if (keywords.some((keyword) => haystack.includes(keyword))) {
      topics.add(topic);
    }
  });

  return Array.from(topics);
}

async function addInAppNotification(uid, title, body, type) {
  await admin.firestore().collection("users").doc(uid)
      .collection("notifications")
      .add({
        title,
        body,
        type,
        createdAt: admin.firestore.Timestamp.now(),
        read: false,
      });
}

exports.generateAgoraToken = onCall(async (request) => {
  // Authentication check
  if (!request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }

  if (!APP_ID || !APP_CERTIFICATE) {
    throw new HttpsError(
        "failed-precondition",
        "Agora credentials are not configured on the server.",
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
    const userIdSet = new Set(remindersSnapshot.docs.map((d) => d.id));

    // Also notify the host
    userIdSet.add(call.hostId);

    // Notify users who follow matching topics/moods
    const callTopics = extractCallTopics(call);
    if (callTopics.length > 0) {
      const topicChunks = chunkArray(callTopics, 10);
      for (const topicChunk of topicChunks) {
        const topicFollowersSnapshot = await admin.firestore()
            .collection("users")
            .where("followedTopics", "array-contains-any", topicChunk)
            .get();

        topicFollowersSnapshot.docs.forEach((followerDoc) => {
          userIdSet.add(followerDoc.id);
        });
      }
    }

    // Get tokens + create in-app notifications
    const tokens = [];
    const userIds = Array.from(userIdSet);
    for (const userId of userIds) {
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (userDoc.exists) {
        const user = userDoc.data();
        if (user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      }

      await addInAppNotification(
          userId,
          "Call Starting!",
          `The call "${call.title}" is starting now!`,
          "call_start",
      );
    }

    // Send a push notification
    if (tokens.length > 0) {
      const message = {
        notification: {
          title: "Call Starting!",
          body: `The call "${call.title}" is starting now!`,
        },
        data: {
          callId: callId,
          topics: callTopics.join(","),
        },
        tokens: tokens,
      };

      try {
        await admin.messaging().sendMulticast(message);
        console.log(`Notifications sent for call ${callId} to ${userIds.length} users.`);
      } catch (error) {
        console.error(`Error sending notifications for call ${callId}:`, error);
      }
    }
  }

  return null;
});
