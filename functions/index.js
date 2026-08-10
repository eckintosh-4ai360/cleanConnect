/* eslint-disable max-len */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const axios = require('axios');

initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// SETUP
//
// Store your Paystack secret key in Firebase Secret Manager:
//   firebase functions:secrets:set PAYSTACK_SECRET_KEY
//
// Then enter your secret key when prompted (sk_test_... or sk_live_...).
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Callable Cloud Function: initializePaystackTransaction
 *
 * Called by the Flutter app to initialize a Paystack transaction
 * and receive an access_code. The Flutter SDK then uses this
 * access_code to launch the Paystack payment UI.
 *
 * Expected request data:
 *   { email: string, amount: number (smallest unit), currency: string, metadata: object }
 *
 * Returns:
 *   { access_code: string, reference: string }
 */
exports.initializePaystackTransaction = onCall(
  {
    // Pull the secret from Firebase Secret Manager
    secrets: ['PAYSTACK_SECRET_KEY'],
    region: 'us-central1',
  },
  async (request) => {
    // ── Auth check ─────────────────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'You must be signed in to make a payment.',
      );
    }

    const { email, amount, currency = 'GHS', metadata = {} } = request.data;

    // ── Input validation ───────────────────────────────────────────────────
    if (!email || typeof email !== 'string') {
      throw new HttpsError('invalid-argument', 'A valid email address is required.');
    }
    if (!amount || typeof amount !== 'number' || amount <= 0) {
      throw new HttpsError('invalid-argument', 'Amount must be a positive number (in smallest currency unit).');
    }

    const secretKey = process.env.PAYSTACK_SECRET_KEY;
    if (!secretKey) {
      console.error('[Paystack] PAYSTACK_SECRET_KEY secret is not set.');
      throw new HttpsError('internal', 'Payment service is not configured.');
    }

    // ── Call Paystack Initialize Transaction API ───────────────────────────
    try {
      const paystackResponse = await axios.post(
        'https://api.paystack.co/transaction/initialize',
        {
          email,
          amount,
          currency,
          metadata: {
            ...metadata,
            user_uid: request.auth.uid,
          },
        },
        {
          headers: {
            Authorization: `Bearer ${secretKey}`,
            'Content-Type': 'application/json',
          },
          timeout: 15000,
        },
      );

      const { status, data, message } = paystackResponse.data;

      if (!status || !data?.access_code) {
        console.error('[Paystack] Unexpected API response:', paystackResponse.data);
        throw new HttpsError('internal', message || 'Failed to initialize payment.');
      }

      console.log(
        `[Paystack] Transaction initialized — reference: ${data.reference}, uid: ${request.auth.uid}`,
      );

      return {
        access_code: data.access_code,
        reference: data.reference,
        authorization_url: data.authorization_url,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;

      const apiError = err?.response?.data?.message;
      console.error('[Paystack] API error:', apiError || err.message);
      throw new HttpsError(
        'internal',
        apiError || 'Could not reach payment service. Please try again.',
      );
    }
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Firestore Trigger: notifyRidersOnNewPickup
//
// Fires whenever a customer creates a new pickup request (root `pickupRequests`
// collection). Broadcasts a data-only FCM push to every rider with a stored
// `fcmToken` so the app can show an on-screen "incoming request" alert with
// vibration, even in the background or when the app is killed (Android).
// ─────────────────────────────────────────────────────────────────────────────
exports.notifyRidersOnNewPickup = onDocumentCreated(
  { document: 'pickupRequests/{requestId}', region: 'us-central1' },
  async (event) => {
    const data = event.data?.data();
    if (!data || data.status !== 'pending') return;

    const requestId = event.params.requestId;
    const db = getFirestore();

    const ridersSnap = await db.collection('riders').get();
    const tokens = ridersSnap.docs
      .map((doc) => doc.data().fcmToken)
      .filter((token) => typeof token === 'string' && token.length > 0);

    if (tokens.length === 0) {
      console.log(`[notifyRidersOnNewPickup] No rider tokens found for request ${requestId}.`);
      return;
    }

    const binTypes = Array.isArray(data.binTypes) ? data.binTypes : [];

    const message = {
      data: {
        type: 'new_pickup_request',
        requestId,
        customerId: data.customerId || '',
        customerName: data.customerName || 'Customer',
        location: data.location || '',
        timeSlot: data.timeSlot || '',
        binTypes: JSON.stringify(binTypes),
      },
      android: {
        priority: 'high',
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { contentAvailable: true } },
      },
      tokens,
    };

    const response = await getMessaging().sendEachForMulticast(message);
    console.log(
      `[notifyRidersOnNewPickup] request ${requestId}: sent to ${tokens.length} riders, ` +
        `success=${response.successCount}, failure=${response.failureCount}`,
    );
  },
);
