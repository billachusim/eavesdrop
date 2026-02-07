const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { RtcTokenBuilder, RtcRole } = require("agora-token");

admin.initializeApp();

// Your Agora credentials
const APP_ID = "7cbfdc57592f47b2a939e2838238f066";
const APP_CERTIFICATE = "9bca5f09b5ab41bfbb09b15230835f90";

exports.generateAgoraToken = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const channelName = data.channelName;
  if (!channelName || typeof channelName !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      'The function must be called with "channelName".'
    );
  }

  // --- THE CRITICAL FIX IS HERE ---
  // Use the UID passed from the client if it exists and is a valid number.
  // This allows the admin to have a static UID like 1.
  // For regular users, if no UID is passed or it's invalid, it safely defaults to 0,
  // which tells Agora to assign a dynamic UID.
  const uid = data.uid && typeof data.uid === 'number' ? data.uid : 0;
  // ---------------------------------

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
      uid, // Use the corrected UID
      role,
      privilegeExpiredTs
    );

    console.log(`Successfully generated token: ${token}`);
    return { token: token };

  } catch (error) {
    console.error("Error generating Agora token:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to generate Agora token."
    );
  }
});
