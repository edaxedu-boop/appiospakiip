const pool = require('../db');

// Helper to send push notification
async function sendPushNotification(toRole, toId, title, body, data = {}) {
    try {
        let table = '';
        if (toRole === 'restaurant') table = 'restaurants';
        else if (toRole === 'rider') table = 'riders';
        else if (toRole === 'client') table = 'clients';
        else if (toRole === 'admin') table = 'admins';
        else return;

        // Fetch token from db
        const { rows } = await pool.query(`SELECT fcm_token FROM ${table} WHERE id = $1`, [toId]);
        if (rows.length === 0 || !rows[0].fcm_token) {
            console.log(`[Push Notification MOCK] User ${toRole} (ID: ${toId}) has no FCM token. Message: "${title} - ${body}"`);
            return;
        }

        const token = rows[0].fcm_token;
        await sendFcmMessage(token, title, body, data);
    } catch (e) {
        console.error('Error sending push notification:', e);
    }
}

// Send to all available/online riders
async function notifyAllAvailableRiders(title, body, data = {}) {
    try {
        const { rows } = await pool.query("SELECT id, fcm_token FROM riders WHERE status = 'available' AND active = true");
        const tokens = rows.map(r => r.fcm_token).filter(t => !!t);

        console.log(`[Push Notification] Notifying ${rows.length} available riders. message: "${title}"`);

        for (let r of rows) {
            if (r.fcm_token) {
                await sendFcmMessage(r.fcm_token, title, body, data);
            } else {
                console.log(`[Push Notification MOCK] Rider (ID: ${r.id}) has no FCM token. Message: "${title} - ${body}"`);
            }
        }
    } catch (e) {
        console.error('Error notifying available riders:', e);
    }
}

async function sendFcmMessage(fcmToken, title, body, data = {}) {
    // If user has firebase-admin credentials configured, send real notification.
    // Otherwise, simulate/log.
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
    
    if (!serviceAccountPath) {
        console.log(`[Push Notification Send] FCM Token: ${fcmToken} | Title: "${title}" | Body: "${body}" | Data:`, data);
        return;
    }

    try {
        const admin = require('firebase-admin');
        if (admin.apps.length === 0) {
            const serviceAccount = require(serviceAccountPath);
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
        }
        
        await admin.messaging().send({
            token: fcmToken,
            notification: {
                title,
                body
            },
            data: {
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'high_importance_channel'
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1
                    }
                }
            }
        });
        console.log(`[Push Notification Success] Sent to token ${fcmToken.substring(0, 10)}...`);
    } catch (err) {
        console.error('[Push Notification Error] Failed to send real FCM message:', err.message);
    }
}

module.exports = {
    sendPushNotification,
    notifyAllAvailableRiders
};
