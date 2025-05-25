/* eslint-disable */
// handlers フォルダから関数を再エクスポート
exports.callVertexAI              = require("./handlers/callVertexAI");
exports.generateQuestionFromImage = require("./handlers/generateQuestionFromImage");
exports.callGeminiOCR             = require("./handlers/geminiOcrHandler").callGeminiOCR;
exports.callVisionOCR             = require("./handlers/visionOcrHandler").callVisionOCR;
