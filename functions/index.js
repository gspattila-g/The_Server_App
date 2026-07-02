const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap) => {
    const notification = snap.data();
    const receiverId = notification.receiverId;
    const senderId = notification.senderId;

    if (receiverId === senderId) return null;

    const userDoc = await getFirestore()
      .collection('userProfiles')
      .doc(receiverId)
      .get();

    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return null;

    const titles = {
      like: '❤️ Új lájk',
      comment: '💬 Új komment',
      message: '✉️ Új üzenet',
    };

    const title = titles[notification.type] ?? 'Új értesítés';
    const body = notification.message;

    try {
      await getMessaging().send({
        token: fcmToken,
        notification: { title, body },
        data: {
          type: notification.type ?? '',
          eventId: notification.eventId ?? '',
        },
        android: {
          priority: 'high',
          notification: { channelId: 'high_importance_channel' },
        },
      });
    } catch (error) {
      if (
        error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered'
      ) {
        await getFirestore()
          .collection('userProfiles')
          .doc(receiverId)
          .update({ fcmToken: require('firebase-admin/firestore').FieldValue.delete() });
      }
    }

    return null;
  });
