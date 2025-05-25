/* eslint-disable */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const vision                 = require("@google-cloud/vision");
const axios                  = require("axios");
const { admin, db, authClient } = require("../lib");

module.exports = onCall(
  { region: "us-central1", memory: "2GiB", timeoutSeconds: 120 },
  async (req) => {
    try {
      // 1) 認証 & 制限
      if (!req.auth) throw new HttpsError("unauthenticated", "ログインが必要です。");
      const uid = req.auth.uid;
      const imageBase64 = req.data?.imageBase64;
      if (!imageBase64) throw new HttpsError("invalid-argument", "imageBase64 がありません。");

      const limit   = 50;
      const today   = new Date().toISOString().slice(0, 10);
      const usageRef= db.collection("ai_usage").doc(`${uid}_${today}`);
      const usage   = (await usageRef.get()).data() || { count: 0 };
      if (usage.count >= limit) {
        throw new HttpsError("resource-exhausted", "本日の無料生成回数上限に達しました。");
      }

      // 2) OCR
      const visionClient = new vision.ImageAnnotatorClient();
      const [det]        = await visionClient.textDetection({
        image: { content: Buffer.from(imageBase64, "base64") },
      });
      const rawText = det.textAnnotations?.[0]?.description?.trim();
      if (!rawText) throw new HttpsError("not-found", "文字を検出できませんでした。");

      // 3) Vertex 生成
      const prompt = `
以下のOCRテキストから日本語の真偽問題を1問だけ作り、JSONのみ返してください。
{
  "questionText": "<～である。>",
  "answer": true,
  "explanation": "<30-120字>",
  "hint": "<任意>"
}
"""${rawText.slice(0, 4000)}"""`;

      const client     = await authClient.getClient();
      const { token }  = await client.getAccessToken();
      const project    = process.env.GCLOUD_PROJECT;
      const location   = "us-central1";
      const endpoint   =
        `https://${location}-aiplatform.googleapis.com/v1/projects/${project}` +
        `/locations/${location}/publishers/google/models/text-bison:predict`;

      const resp = await axios.post(
        endpoint,
        { instances: [{ prompt }], parameters: { temperature: 0.4, maxOutputTokens: 512 } },
        { headers: { Authorization: `Bearer ${token}` } }
      );

      const textOut = resp.data?.predictions?.[0]?.content?.trim();
      if (!textOut) throw new HttpsError("internal", "Vertex AI 応答なし");

      let payload;
      try { payload = JSON.parse(textOut); }
      catch { throw new HttpsError("internal", "生成結果のJSON解析失敗"); }

      // 4) 使用量 +1
      await usageRef.set({ count: usage.count + 1 }, { merge: true });

      // 5) 返却
      return payload;
    } catch (err) {
      console.error("[generateQuestionFromImage] Error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err.message || "サーバーエラー");
    }
  }
);
