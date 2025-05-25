/* eslint-disable */
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
async function callGemini({
  contents,
  systemContext = "",
  temperature = 0.7,
  maxTokens = 1024,
  topP = 0.9,
  maxAttempts = 3,
}) {
  const client = await authClient.getClient();
  const { token } = await client.getAccessToken();
  const project = process.env.GCLOUD_PROJECT;
  const location = "us-central1";
  const modelId = "gemini-2.0-flash";
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
      timeout: 30000,
    });

    const candidate = resp.data?.candidates?.[0] || {};
    const chunk = (candidate.content?.parts || [])
      .map((p) => p.text || "")
      .join("");
    allText += chunk;
    finishReason = candidate.finishReason || "";

    if (finishReason !== "MAX_TOKENS") break;

    contents = [...contents, { role: "model", parts: [{ text: chunk }] }];
    attempt += 1;
  }

  return { text: allText, finishReason };
}

// ───────── Vision OCR ヘルパ ─────────
async function callVisionOCR({ imageBase64 }) {
  const client = await authClient.getClient();
  const { token } = await client.getAccessToken();

  const endpoint = "https://vision.googleapis.com/v1/images:annotate";
  const payload = {
    requests: [
      {
        image: { content: imageBase64 },
        features: [{ type: "TEXT_DETECTION", maxResults: 1 }],
      },
    ],
  };

  const resp = await axios.post(endpoint, payload, {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    timeout: 30000,
  });

  const annotations = resp.data?.responses?.[0]?.textAnnotations;
  const text =
    annotations && annotations.length ? annotations[0].description : "";

  return { text };
}

module.exports = { admin, db, authClient, callGemini, callVisionOCR };
