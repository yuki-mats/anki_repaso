/* eslint-disable */
//..functions/handlers/callVertexAI.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { admin, db, callGemini } = require("../lib");   // ← 共通ライブラリ1本だけ

module.exports = onCall({ region: "us-central1" }, async (req) => {
  try {
    // 1) 認証 & 入力チェック
    if (!req.auth) throw new HttpsError("unauthenticated", "ログインが必要です。");
    const uid = req.auth.uid;
    const { memoId, message, questionId = "", systemContext = "" } = req.data || {};
    if (!message || typeof message !== "string") {
      throw new HttpsError("invalid-argument", "message が空です。");
    }

    // 2) licenseName 取得
    let licenseName = "";
    if (questionId) {
      try {
        const qSnap = await db.doc(`questions/${questionId}`).get();
        const qsId  = qSnap.exists ? qSnap.data().questionSetId || "" : "";
        const qsSnap= qsId ? await db.doc(`questionSets/${qsId}`).get() : null;
        const folderId = qsSnap?.exists ? qsSnap.data().folderId || "" : "";
        const fSnap = folderId ? await db.doc(`folders/${folderId}`).get() : null;
        licenseName = fSnap?.exists ? fSnap.data().licenseName || "" : "";
      } catch (e) { console.error("[callVertexAI] licenseName fetch error:", e); }
    }

    // 3) Firestore 保存
    let targetMemoId = memoId;
    const ts = admin.firestore.FieldValue.serverTimestamp();
    if (!targetMemoId) {
      const doc = await db.collection("memos").add({
        questionId,
        visibility    : "private",
        isDeleted     : false,
        licenseName,
        content       : message,
        memoType      : "question",
        createdById   : uid,
        createdAt     : ts,
        title         : "",
        contentFormat : "plain_text",
        attachedImages: [],
        likeCount     : 0,
        replyCount    : 0,
        isResolved    : false,
        isAIGenerated : false,
        updatedById   : uid,
        updatedAt     : ts,
        deletedAt     : null,
      });
      targetMemoId = doc.id;
    } else {
      await db.collection(`memos/${targetMemoId}/replies`).add({
        content       : message,
        parentReplyId : null,
        createdById   : uid,
        createdAt     : ts,
        isAIGenerated : false,
        isDeleted     : false,
      });
      await db.doc(`memos/${targetMemoId}`).update({
        replyCount : admin.firestore.FieldValue.increment(1),
        updatedById: uid,
        updatedAt  : ts,
      });
    }

    // 4) 履歴取得
    const replySnap = await db
      .collection(`memos/${targetMemoId}/replies`)
      .orderBy("createdAt", "asc")
      .limitToLast(10)
      .get();
    const history = replySnap.docs.map((d) => ({
      role : d.data().createdById === uid ? "user" : "model",
      parts: [{ text: d.data().content }],
    }));

    // 5) Gemini
    const contents = [...history, { role: "user", parts: [{ text: message }] }];
    const { text: aiText } = await callGemini({ contents, systemContext });

    // 6) AI 応答保存
    await db.collection(`memos/${targetMemoId}/replies`).add({
      content       : aiText,
      parentReplyId : null,
      createdById   : "gemini",
      createdAt     : ts,
      isAIGenerated : true,
      isDeleted     : false,
    });
    await db.doc(`memos/${targetMemoId}`).update({
      replyCount : admin.firestore.FieldValue.increment(1),
      updatedById: "gemini",
      updatedAt  : ts,
    });

    // 7) クライアントへ返却
    return { reply: aiText, memoId: targetMemoId };
  } catch (err) {
    console.error("[callVertexAI] Error:", err);
    if (err instanceof HttpsError) throw err;
    if (err.response?.data) {
      throw new HttpsError("internal", `Gemini response error: ${JSON.stringify(err.response.data)}`);
    }
    throw new HttpsError("internal", `Unknown exception: ${err.message}`);
  }
});
