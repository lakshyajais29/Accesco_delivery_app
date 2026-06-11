import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
admin.initializeApp();

const db = admin.firestore();
const fcm = admin.messaging();

// ── Triggered when a vibe_check is CREATED ──────────────────────────────
export const onVibeCheckCreated = functions.firestore
  .document('vibe_checks/{vibeCheckId}')
  .onCreate(async (snap, ctx) => {
    const data = snap.data();
    const vibeCheckId = ctx.params.vibeCheckId;
    const friendIds: string[] = data.selectedFriendIds ?? [];

    // Fetch FCM tokens of all selected friends
    const tokens: string[] = [];
    for (const uid of friendIds) {
      const userDoc = await db.collection('users').doc(uid).get();
      const token = userDoc.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    // Send multicast notification
    await fcm.sendEachForMulticast({
      tokens,
      notification: {
        title: 'InstaStyle — Vibe Check 👀',
        body: `${data.creatorName} wants your take on ${data.productName}`,
      },
      data: {
        vibeCheckId,
        screen: 'friend_reaction',
      },
      android: {
        notification: {
          channelId: 'vibe_check',
          priority: 'high',
        },
        // Quick-action buttons handled by app
      },
      apns: {
        payload: {
          aps: {
            category: 'VIBE_CHECK', // maps to UNNotificationCategory
            'mutable-content': 1,
          },
        },
      },
    });
  });

// ── Triggered when a REACTION is written ────────────────────────────────
export const onReactionWritten = functions.firestore
  .document('vibe_check_reactions/{vibeCheckId}/reactions/{friendId}')
  .onWrite(async (change, ctx) => {
    const vibeCheckId = ctx.params.vibeCheckId;

    // Get the vibe check to notify creator
    const vibeDoc = await db.collection('vibe_checks').doc(vibeCheckId).get();
    if (!vibeDoc.exists) return;
    const vibeData = vibeDoc.data()!;

    const reaction = change.after.data()?.reaction as string;
    const friendName = change.after.data()?.friendName as string;

    // Notify creator of new reaction
    const creatorDoc = await db.collection('users').doc(vibeData.creatorId).get();
    const creatorToken = creatorDoc.data()?.fcmToken;

    if (creatorToken) {
      await fcm.send({
        token: creatorToken,
        notification: {
          title: `${friendName} reacted ${reaction === 'YES' ? '🔥' : reaction === 'MAYBE' ? '🤔' : '❌'}`,
          body: `${friendName} said ${reaction} to ${vibeData.productName}`,
        },
        data: { vibeCheckId, screen: 'results' },
      });
    }

    // ── FOMO trigger: check total reactions vs stock ──────────────────────
    const reactionsSnap = await db
      .collection('vibe_check_reactions')
      .doc(vibeCheckId)
      .collection('reactions')
      .get();

    const yesCount = reactionsSnap.docs
      .filter(d => d.data().reaction === 'YES').length;

    const productDoc = await db.collection('products').doc(vibeData.productId).get();
    const stock = productDoc.data()?.stock ?? 99;

    // If YES votes > 1 AND stock is low: send FOMO alert to creator
    if (yesCount >= 1 && stock <= 2 && creatorToken) {
      await fcm.send({
        token: creatorToken,
        notification: {
          title: '⚡ Stock dropping!',
          body: `Only ${stock} left in your size — your crew says YES!`,
        },
        data: { vibeCheckId, screen: 'results', fomo: 'true' },
      });
    }
  });