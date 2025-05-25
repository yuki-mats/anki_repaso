/* eslint-disable */
/* 必要パッケージ（handlers 直下でインストール済み想定）
   npm install @google-cloud/vertexai firebase-functions firebase-admin
*/
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { VertexAI }            = require("@google-cloud/vertexai");
const admin                    = require("firebase-admin");

// 既に初期化済みかチェックしてから初期化
if (!admin.apps.length) {
  admin.initializeApp();
}

/* ────────────── 環境設定 ────────────── */
const project  = process.env.GCLOUD_PROJECT;
const location = "us-central1";

/* ────────────── Gemini 初期化 ────────────── */
const vertexAi = new VertexAI({ project, location });
const gemini   = vertexAi.getGenerativeModel({
  model:     "gemini-1.5-pro",
  publisher: undefined,
});

/**
 * HTTPS Callable: callGeminiOCR
 * data: { imageBase64: string, mimeType?: string }
 * return: { text: string }
 */
const callGeminiOCR = onCall(
  { region: location, maxInstances: 5 },
  async (req) => {
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "ログインが必要です。");
    }

    const { imageBase64, mimeType = "image/jpeg" } = req.data || {};
    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "imageBase64 が空です。");
    }

    const prompt =
      "この画像から読み取れる日本語テキストをそのまま抽出してください。" +
      "余計な説明は不要です。";

    try {
      const response = await gemini.generateContent({
        contents: [
          {
            role: "user",
            parts: [
              { inlineData: { data: imageBase64, mimeType } },
              { text: prompt },
            ],
          },
        ],
        generationConfig: {
          temperature:     0.0,
          maxOutputTokens: 2048,
        },
      });

      const text =
        response?.response?.candidates?.[0]?.content?.parts?.[0]?.text || "";

      if (!text.trim()) {
        throw new HttpsError(
          "not-found",
          "画像からテキストを抽出できませんでした。"
        );
      }

      return { text };
    } catch (err) {
      console.error("[callGeminiOCR] OCR Error:", err);
      const message = err?.message || "Gemini API の呼び出しに失敗しました。";
      throw new HttpsError("internal", `OCR失敗: ${message}`);
    }
  }
);

module.exports = { callGeminiOCR };
