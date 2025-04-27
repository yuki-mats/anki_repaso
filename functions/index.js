/* eslint-disable */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleAuth }         = require("google-auth-library");
const admin                  = require("firebase-admin");
const axios                  = require("axios");

admin.initializeApp();

const authClient = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/cloud-platform"],
});

exports.callVertexAI = onCall({ region: "us-central1" }, async (req) => {
  /* ── 認証 & 入力チェック ─────────────────────────────── */
  if (!req.auth) {
    throw new HttpsError("unauthenticated", "ログインが必要です。");
  }
  const userMessage = req.data.message;
  if (typeof userMessage !== "string" || userMessage.trim() === "") {
    throw new HttpsError("invalid-argument", "message が空です。");
  }

  try {
    /* ── アクセストークン取得 ───────────────────────────── */
    const client   = await authClient.getClient();
    const tokenObj = await client.getAccessToken();
    const token    = tokenObj.token;

    /* ── エンドポイント ────────────────────────────────── */
    const project  = process.env.GCLOUD_PROJECT;
    const location = "us-central1";
    const modelId  = "gemini-2.0-flash";
    const url =
      "https://" + location + "-aiplatform.googleapis.com/v1/projects/" +
      project + "/locations/" + location +
      "/publishers/google/models/" + modelId + ":generateContent";

    /* ── リクエストペイロード ──────────────────────────── */
    const body = {
      contents: [{ role: "user", parts: [{ text: userMessage }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 1024 },
    };

    /* ── 呼び出し ─────────────────────────────────────── */
    const resp = await axios.post(url, body, {
      headers: {
        Authorization: "Bearer " + token,
        "Content-Type": "application/json",
      },
      timeout: 10000,
    });

    if (resp.status !== 200) {
      throw new HttpsError(
        "internal",
        "Gemini HTTP " + resp.status + ": " + JSON.stringify(resp.data)
      );
    }

    /* ── 本文だけを抽出して返す ────────────────────────── */
    let parts = [];
    if (resp.data &&
        resp.data.candidates &&
        resp.data.candidates.length > 0 &&
        resp.data.candidates[0].content &&
        resp.data.candidates[0].content.parts) {
      parts = resp.data.candidates[0].content.parts;
    }
    const text = (parts.length > 0 && parts[0].text) ? parts[0].text : "(empty)";
    return { reply: text };

  } catch (err) {
    if (err instanceof HttpsError) throw err;

    if (err.response && err.response.data) {
      throw new HttpsError(
        "internal",
        "Gemini response: " + JSON.stringify(err.response.data)
      );
    }
    throw new HttpsError("internal", "Exception: " + err.message);
  }
});
