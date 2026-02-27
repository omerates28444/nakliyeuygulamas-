const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

const REGION = "us-central1";

function normalizeTokens(userData) {
  const raw =
    userData?.extra?.fcmTokens ??
    userData?.fcmTokens ??
    [];

  if (!Array.isArray(raw)) return [];
  // sadece string, trim, boş olmayan + unique
  return [...new Set(raw.map((t) => (typeof t === "string" ? t.trim() : "")).filter(Boolean))];
}

async function cleanupBadTokens(userRef, tokens, multicastRes) {
  // Hatalı tokenları temizle (çok önerilir)
  const bad = [];
  multicastRes.responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error?.errorInfo?.code || r.error?.code || "";
    // En yaygın “bozuk token” hataları
    if (
      code.includes("messaging/registration-token-not-registered") ||
      code.includes("messaging/invalid-registration-token")
    ) {
      bad.push(tokens[i]);
    }
  });

  if (bad.length === 0) return;

  // extra.fcmTokens içinden sil
  await userRef.set(
    {
      extra: {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...bad),
      },
    },
    { merge: true }
  );

  console.log("CLEANUP: removed bad tokens:", bad);
}

// 1) Teklif gelince (shipper’a)
// 1) Teklif gelince (shipper’a)
exports.onOfferCreated = onDocumentCreated(
  { document: "offers/{offerId}", region: REGION },
  async (event) => {
    try {
      const data = event.data?.data();
      console.log("OFFER CREATED DATA:", data);
      if (!data) return;

      // 👇 DEĞİŞTİRDİĞİMİZ KISIM BURASI 👇
      let shipperId = data.shipperId;

      if (!shipperId && data.loadId) {
        const loadDoc = await admin.firestore().collection("loads").doc(data.loadId).get();
        shipperId = loadDoc.data()?.shipperId;
      }

      console.log("BULUNAN SHIPPER ID:", shipperId);
      if (!shipperId) {
         console.log("İlanın sahibi bulunamadı, bildirim atılamıyor.");
         return;
      }
      // 👆 DEĞİŞTİRDİĞİMİZ KISIM BURASI 👆

      const userRef = admin.firestore().collection("users").doc(shipperId);
      const userDoc = await userRef.get();
      const userData = userDoc.data() || {};
      console.log("USER DATA:", userData);

      const tokens = normalizeTokens(userData);
      console.log("TOKENS:", tokens);

      if (tokens.length === 0) {
        console.log("TOKEN YOK!");
        return;
      }

      const res = await admin.messaging().sendEachForMulticast({
        notification: {
          title: "Yeni Teklif 🚛",
          body: `${data.driverName || "Bir şoför"} sana teklif verdi`,
        },
        tokens,
      });

      console.log("SEND RESULT:", {
        successCount: res.successCount,
        failureCount: res.failureCount,
      });

      // bozuk token temizliği
      await cleanupBadTokens(userRef, tokens, res);
    } catch (e) {
      console.error("ERROR onOfferCreated:", e);
    }
  }
);

// 2) Teklif kabul edilince (driver’a)
exports.onOfferAccepted = onDocumentUpdated(
  { document: "offers/{offerId}", region: REGION },
  async (event) => {
    try {
      const before = event.data?.before?.data();
      const after = event.data?.after?.data();

      console.log("BEFORE:", before);
      console.log("AFTER:", after);

      if (!before || !after) return;

      // sadece status: sent/countered -> accepted geçişinde çalışsın
      if (before.status === "accepted" || after.status !== "accepted") {
        console.log("ŞART SAĞLANMADI");
        return;
      }

      const driverId = after.driverId;
      console.log("DRIVER ID:", driverId);
      if (!driverId) return;

      const userRef = admin.firestore().collection("users").doc(driverId);
      const userDoc = await userRef.get();
      const userData = userDoc.data() || {};
      console.log("USER DATA:", userData);

      const tokens = normalizeTokens(userData);
      console.log("TOKENS:", tokens);

      if (tokens.length === 0) {
        console.log("TOKEN YOK!");
        return;
      }

      const res = await admin.messaging().sendEachForMulticast({
        notification: {
          title: "Teklif Kabul Edildi 🎉",
          body: "Yük sahibi teklifini kabul etti!",
        },
        tokens,
      });

      console.log("SEND RESULT:", {
        successCount: res.successCount,
        failureCount: res.failureCount,
      });

      // bozuk token temizliği
      await cleanupBadTokens(userRef, tokens, res);
    } catch (e) {
      console.error("ERROR onOfferAccepted:", e);
    }
  }
);