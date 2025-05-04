/* eslint-disable */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleAuth }         = require("google-auth-library");
const admin                  = require("firebase-admin");
const axios                  = require("axios");

admin.initializeApp();
const db = admin.firestore();

// Vertex 用認証クライアント
const authClient = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/cloud-platform"],
});

exports.callVertexAI = onCall({ region: "us-central1" }, async (req) => {
  try {
    /* ───────────────────────────────
     * 1) 認証 & 入力チェック
     * ─────────────────────────────── */
    if (!req.auth) {
      throw new HttpsError("unauthenticated", "ログインが必要です。");
    }
    const uid = req.auth.uid;
    const {
      memoId,
      message,
      questionId    = "",
      systemContext = "",
    } = req.data || {};

    if (typeof message !== "string" || message.trim() === "") {
      throw new HttpsError("invalid-argument", "message が空です。");
    }

    /* ───────────────────────────────
     * 2) フォルダの licenseName を取得
     * ─────────────────────────────── */
    let licenseName = "";
    if (questionId) {
      try {
        const qSnap = await db.doc(`questions/${questionId}`).get();
        if (qSnap.exists) {
          const { questionSetId = "" } = qSnap.data() || {};
          if (questionSetId) {
            const qsSnap = await db.doc(`questionSets/${questionSetId}`).get();
            if (qsSnap.exists) {
              const { folderId = "" } = qsSnap.data() || {};
              if (folderId) {
                const fSnap = await db.doc(`folders/${folderId}`).get();
                if (fSnap.exists) {
                  licenseName = (fSnap.data() || {}).licenseName || "";
                }
              }
            }
          }
        }
      } catch (err) {
        console.error("[callVertexAI] licenseName 取得失敗:", err);
        // licenseName が取得できなくても致命的ではないので処理続行
      }
    }

    /* ───────────────────────────────
     * 3) Firestore にユーザー発話を保存
     * ─────────────────────────────── */
    let targetMemoId = memoId;
    const now        = admin.firestore.FieldValue.serverTimestamp();

    if (!targetMemoId) {
      const memoRef = await db.collection("memos").add({
        questionId,
        visibility    : "private",
        isDeleted     : false,
        licenseName   : licenseName,     // ★ 追加 ★
        content       : message,
        memoType      : "question",
        createdById   : uid,
        createdAt     : now,
        title         : "",
        contentFormat : "plain_text",
        attachedImages: [],
        likeCount     : 0,
        replyCount    : 0,
        isResolved    : false,
        isAIGenerated : false,
        updatedById   : uid,
        updatedAt     : now,
        deletedAt     : null,
      });
      targetMemoId = memoRef.id;
    } else {
      await db.collection(`memos/${targetMemoId}/replies`).add({
        content       : message,
        parentReplyId : null,
        createdById   : uid,
        createdAt     : now,
        isAIGenerated : false,
        isDeleted     : false,
      });
      await db.doc(`memos/${targetMemoId}`).update({
        replyCount : admin.firestore.FieldValue.increment(1),
        updatedById: uid,
        updatedAt  : now,
      });
    }

    /* ───────────────────────────────
     * 4) 直近 10 件の会話履歴を構築
     * ─────────────────────────────── */
    const replySnap = await db
      .collection(`memos/${targetMemoId}/replies`)
      .orderBy("createdAt", "asc")
      .limitToLast(10)
      .get();
    const history = replySnap.docs.map((d) => {
      const role = d.data().createdById === uid ? "user" : "model";
      return {
        role,
        parts: [{ text: d.data().content }],
      };
    });

    /* ───────────────────────────────
     * 5) Vertex AI 呼び出し
     * ─────────────────────────────── */
    const contents = [
      ...history,
      { role: "user", parts: [{ text: message }] },
    ];
    const payload = {
      contents,
      ...(systemContext
        ? {
            systemInstruction: {
              parts: [{ text: systemContext }],
            },
          }
        : {}),
      generationConfig: {
        temperature     : 0.7,
        maxOutputTokens : 256,
        topP            : 0.9,
      },
    };

    console.log("[callVertexAI] payload:", JSON.stringify(payload));

    const client    = await authClient.getClient();
    const { token } = await client.getAccessToken();
    const project   = process.env.GCLOUD_PROJECT;
    const location  = "us-central1";
    const modelId   = "gemini-2.0-flash";
    const url =
      `https://${location}-aiplatform.googleapis.com/v1/projects/${project}` +
      `/locations/${location}/publishers/google/models/${modelId}:generateContent`;

    const resp = await axios.post(
      url,
      payload,
      {
        headers: {
          Authorization : `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        timeout: 10000,
      }
    );
    const aiText =
      resp.data?.candidates?.[0]?.content?.parts?.[0]?.text || "(empty)";

    /* ───────────────────────────────
     * 6) Gemini 応答を Firestore に保存
     * ─────────────────────────────── */
    await db.collection(`memos/${targetMemoId}/replies`).add({
      content       : aiText,
      parentReplyId : null,
      createdById   : "gemini",
      createdAt     : now,
      isAIGenerated : true,
      isDeleted     : false,
    });
    await db.doc(`memos/${targetMemoId}`).update({
      replyCount : admin.firestore.FieldValue.increment(1),
      updatedById: "gemini",
      updatedAt  : now,
    });

    /* ───────────────────────────────
     * 7) クライアントへ返却
     * ─────────────────────────────── */
    return { reply: aiText, memoId: targetMemoId };
  } catch (err) {
    console.error("[callVertexAI] Error:", err);
    if (err instanceof HttpsError) {
      throw err;
    }
    if (err.response?.data) {
      throw new HttpsError(
        "internal",
        `Gemini response error: ${JSON.stringify(err.response.data)}`
      );
    }
    throw new HttpsError("internal", `Unknown exception: ${err.message}`);
  }
});
