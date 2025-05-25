/* eslint-disable */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {callVisionOCR}      = require("../lib");
const admin                = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();

exports.callVisionOCR = onCall({region: "us-central1"}, async (req) => {
  if (!req.auth) {
    throw new HttpsError("unauthenticated", "ログインが必要です。");
  }
  const {imageBase64} = req.data || {};
  if (!imageBase64 || typeof imageBase64 !== "string") {
    throw new HttpsError("invalid-argument", "imageBase64 が空です。");
  }

  try {
    const {text} = await callVisionOCR({imageBase64});
    if (!text.trim()) {
      throw new HttpsError("not-found", "画像からテキストを検出できませんでした。");
    }
    return {text};
  } catch (e) {
    console.error("[callVisionOCR] error:", e);
    throw new HttpsError(
      "internal",
      `OCR に失敗しました: ${e.message || "不明なエラー"}`
    );
  }
});
