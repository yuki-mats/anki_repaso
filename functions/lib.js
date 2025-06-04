/* eslint-disable */
// ..functions/lib.js

const admin = require("firebase-admin");
const { GoogleAuth } = require("google-auth-library");
const axios = require("axios");

// ───────── Firebase 初期化 ─────────
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// ───────── 認証クライアント ─────────
const authClient = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/cloud-platform"],
});

// ───────── Gemini ヘルパ ─────────
// マルチモーダル対応（テキスト＋inline_data(base64Image) を parts に混在させられる）
async function callGemini({
  contents,
  systemContext = "",
  temperature = 0.0,    // OCR 用なのでデフォルトは 0.0
  maxTokens = 2048,     // OCR で使うなら 2048 程度が目安
  topP = 0.9,
  maxAttempts = 1,      // OCR の場合はリトライ不要なら 1 でよい
}) {
  const client = await authClient.getClient();
  const { token } = await client.getAccessToken();
  const project = process.env.GCLOUD_PROJECT;
  const location = "us-central1";          // モデルがサポートされているリージョン
  const modelId = "gemini-2.0-flash";       // 統一して gemini-2.0-flash を使う
  const endpoint =
    `https://${location}-aiplatform.googleapis.com/v1/projects/${project}` +
    `/locations/${location}/publishers/google/models/${modelId}:generateContent`;

  let allText = "";
  let attempt = 0;
  let finishReason = "";

  while (attempt < maxAttempts) {
    const payload = {
      contents,
      ...(systemContext
        ? { systemInstruction: { parts: [{ text: systemContext }] } }
        : {}),
      generationConfig: {
        temperature,
        maxOutputTokens: maxTokens,
        topP,
      },
    };

    const resp = await axios.post(endpoint, payload, {
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      timeout: 60000,
    });

    const candidate = resp.data?.candidates?.[0] || {};
    const chunk = (candidate.content?.parts || [])
      .map((p) => p.text || "")
      .join("");
    allText += chunk;
    finishReason = candidate.finishReason || "";

    if (finishReason !== "MAX_TOKENS") break;

    // 必要に応じて続きリクエスト（OCR では通常不要）
    contents = [...contents, { role: "model", parts: [{ text: chunk }] }];
    attempt += 1;
  }

  return { text: allText, finishReason };
}

module.exports = { admin, db, authClient, callGemini };
