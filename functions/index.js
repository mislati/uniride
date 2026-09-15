const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.notifyDriverOnNewRide = functions.firestore
  .document("ride_requests/{rideId}")
  .onCreate(async (snap, context) => {
    const rideData = snap.data();
    const targetDriverId = rideData.targetDriverId;
    const pickup = rideData.pickupLocation;
    const destination = rideData.destination;
    const price = rideData.price || 200;

    // 1. If there is no target driver, we do nothing
    if (!targetDriverId) {
      return console.log("No target driver ID found.");
    }

    // 2. Fetch the driver's profile to get their FCM Token
    const driverDoc = await admin.firestore().collection("users").doc(targetDriverId).get();
    if (!driverDoc.exists) {
      return console.log("Driver not found.");
    }

    const driverData = driverDoc.data();
    const fcmToken = driverData.fcmToken;

    // 3. If the driver hasn't logged in to generate a token yet, stop
    if (!fcmToken) {
      return console.log("Driver does not have an FCM token.");
    }

    // 4. Build the High-Priority Payload
    const message = {
      token: fcmToken,
      notification: {
        title: "New Ride Request! 🚕",
        body: `Pickup: ${pickup} \nDropoff: ${destination} \nFare: ₦${price}`,
      },
      android: {
        priority: "high", // Forces Android to wake up
        notification: {
          channelId: "high_importance_channel", // Must match the Dart code channel
          sound: "default",
        },
      },
    };

    // 5. Send the signal
    try {
      await admin.messaging().send(message);
      console.log(`Notification sent successfully to driver: ${targetDriverId}`);
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  });