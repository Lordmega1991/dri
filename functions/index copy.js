const functions = require("firebase-functions");
const fetch = require("node-fetch");

exports.criarPasta = functions.https.onRequest(async (req, res) => {
  // ✅ Habilita CORS - ADICIONE Authorization
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(200).send("OK");
  }

  try {
    const {nomePasta} = req.body;

    if (!nomePasta) {
      return res.status(400).json({
        status: "erro",
        mensagem: "Nome da pasta é obrigatório",
      });
    }

    // 🔗 Chama o Apps Script ATUALIZADO (nova URL)
    const response = await fetch(
      "https://script.google.com/macros/s/AKfycbzkGVL_TZDyed2pVlegvtfxh8r4t1-VA8bt5KGtOdKjub_kODil4Akd2lZFVsD_zzHe/exec",
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({nomePasta}),
      },
    );

    const data = await response.text();

    res.status(200).send(data);
  } catch (erro) {
    res.status(500).json({
      status: "erro",
      mensagem: erro.toString(),
    });
  }
});

// ✅ FUNÇÃO UPLOAD DIPLOMA ATUALIZADA
exports.uploadDiploma = functions.https.onRequest(async (req, res) => {
  // ✅ Habilita CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(200).send("OK");
  }

  try {
    // Verifica se é POST
    if (req.method !== "POST") {
      return res.status(405).json({
        status: "erro",
        mensagem: "Método não permitido. Use POST.",
      });
    }

    const {folderId, file, fileName} = req.body;

    if (!folderId || !file || !fileName) {
      return res.status(400).json({
        status: "erro",
        mensagem: "folderId, file e fileName são obrigatórios",
      });
    }

    // 🔗 Chama o Apps Script para upload COM NOVA URL
    const response = await fetch(
      "https://script.google.com/macros/s/AKfycbyIhXtlwvEl3pABuyj1Sy_-BhYhQuGU2tUaqO36foh7bxzkOBbi_psjgZ9wwBoTMPop/exec", // NOVA URL AQUI
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          folderId: folderId,
          file: file,
          fileName: fileName,
          mimeType: "application/pdf",
        }),
      },
    );

    const data = await response.text();

    res.status(200).send(data);
  } catch (erro) {
    console.error("Erro no uploadDiploma:", erro);
    res.status(500).json({
      status: "erro",
      mensagem: erro.toString(),
    });
  }
});
