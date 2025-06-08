/* eslint-disable */
"use strict";

const { onCall, HttpsError }   = require("firebase-functions/v2/https");
const { v4: uuidv4 }           = require("uuid");
const { db, callGemini }       = require("../lib");
const { Timestamp, FieldValue } = require("firebase-admin/firestore");

// ─────────────────────────────────────────────
// 画像 → Gemini で問題生成  (true_false / single_choice / flash_card)
// ─────────────────────────────────────────────
module.exports = onCall({ region: "us-central1" }, async (req) => {
  try {
    /* 1) 認証 */
    if (!req.auth) throw new HttpsError("unauthenticated", "ログインが必要です。");
    const uid     = req.auth.uid;
    const userRef = db.collection("users").doc(uid);

    /* 2) パラメータ */
    const {
      base64Image   = "",
      mimeType      = "image/jpeg",
      questionSetId = "",
      folderId      = "",
      questionType  = "",
      generateCount = 1,          // ★ 追加 ★
    } = req.data || {};

    const genCount = Math.min(Math.max(parseInt(generateCount, 10) || 1, 1), 10); // 1〜10 で安全化
    console.log(`[generateQuestionFromImage] type=${questionType}, cnt=${genCount}`);

    if (!base64Image)   throw new HttpsError("invalid-argument", "base64Image が空です。");
    if (!questionSetId) throw new HttpsError("invalid-argument", "questionSetId が必須です。");

    /* 3) プロンプト雛形 */
    const PROMPTS = {
      true_false: ({n}) => `
以下の画像をOCRして内容を把握し、日本語の正誤問題を **${n}問** 作成してください。

【ルール】
- questionType は "true_false"
- 正答が「正しい」か「間違い」かを判断してください
- 正答が「間違い」の場合は explanationText で どこが誤りか を120文字以内で示す
- 出力は JSON 配列のみ（前後の余分な文字は禁止）

[
  {
    "questionText": "...",
    "questionType": "true_false",
    "correctChoiceText": "正しい" | "間違い",
    "incorrectChoice1Text": "正しい" | "間違い",
    "explanationText": "..."
  }
]`.trim(),

      single_choice: ({n}) => `
以下の画像をOCRして内容を把握し、日本語の四択問題を **${n}問** 作成してください。

【ルール】
- questionType は "single_choice"
- 選択肢は正答1 + 誤答3
- explanationText には「なぜ正答が正しく、誤答が誤りか」を120文字以内で
- 出力は JSON 配列のみ

[
  {
    "questionText": "...",
    "questionType": "single_choice",
    "correctChoiceText": "...",
    "incorrectChoice1Text": "...",
    "incorrectChoice2Text": "...",
    "incorrectChoice3Text": "...",
    "explanationText": "..."
  }
]`.trim(),

      flash_card: ({n}) => `
以下の画像をOCRして内容を把握し、日本語のフラッシュカードを **${n}枚** 作成してください。

【ルール】
- questionType は "flash_card"
- explanationText には補足や覚え方を120文字以内で
- 出力は JSON 配列のみ

[
  {
    "questionText": "...",
    "questionType": "flash_card",
    "correctChoiceText": "...",
    "explanationText": "..."
  }
]`.trim(),
    };

    const prompt = (PROMPTS[questionType] || PROMPTS.single_choice)({ n: genCount });

    /* 4) Gemini 呼び出し */
    const { text: geminiOut } = await callGemini({
      contents:[{
        role:"user",
        parts:[
          { text: prompt },
          { inline_data:{ mime_type: mimeType, data: base64Image } },
        ],
      }],
      temperature:0.3,
      maxTokens  :4096,
    });

    /* 5) JSON パース */
    let qs;
    try {
      const cleaned = (geminiOut || "")
        .replace(/```json\s*/ig,"")
        .replace(/```/g,"")
        .trim();
      qs = JSON.parse(cleaned.match(/\[[\s\S]*\]/)[0]);
      if (!Array.isArray(qs)) throw new Error("not array");
    } catch (e) {
      console.error("JSON parse error:", geminiOut);
      throw new HttpsError("data-loss", "Gemini から有効な JSON 配列が得られませんでした。");
    }

    /* 6) Firestore へバルク保存 */
    const now      = Timestamp.now();
    const qsRef    = db.collection("questionSets").doc(questionSetId);
    const batch    = db.batch();
    const ids      = [];

    qs.slice(0, genCount).forEach((q) => {
      const questionId  = uuidv4();
      const questionRef = db.collection("questions").doc(questionId);

      const baseData = {
        questionSetId,
        questionSetRef : qsRef,
        questionText   : q.questionText,
        questionType   : questionType || q.questionType,
        explanationText: q.explanationText || "",
        memoCount      : 0,
        isOfficialQuestion:false,
        isDeleted      : false,
        createdById    : uid,
        updatedById    : uid,
        createdByRef   : userRef,
        updatedByRef   : userRef,
        createdAt      : now,
        updatedAt      : now,
      };

      let extra = {};
      if (questionType === "true_false") {
        extra = {
          correctChoiceText   : q.correctChoiceText,
          incorrectChoice1Text: q.incorrectChoice1Text,
        };
      } else if (questionType === "single_choice") {
        extra = {
          correctChoiceText   : q.correctChoiceText,
          incorrectChoice1Text: q.incorrectChoice1Text,
          incorrectChoice2Text: q.incorrectChoice2Text,
          incorrectChoice3Text: q.incorrectChoice3Text,
        };
      } else if (questionType === "flash_card") {
        extra = { correctChoiceText: q.correctChoiceText };
      }

      batch.set(questionRef, { ...baseData, ...extra });
      ids.push(questionId);
    });

    // 問題集・フォルダ側のカウント更新
    batch.update(qsRef, {
      questionCount: FieldValue.increment(ids.length),
      updatedAt    : now,
      updatedId    : uid,
    });
    if (folderId) {
      batch.update(db.collection("folders").doc(folderId), {
        questionCount: FieldValue.increment(ids.length),
        updatedAt    : now,
        updatedById  : uid,
      });
    }

    await batch.commit();
    console.log(`saved ${ids.length} questions →`, ids);

    /* 7) 返却 */
    return { questionIds: ids };
  } catch (err) {
    console.error("[generateQuestionFromImage] Error:", err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err.message || "Unknown exception");
  }
});
