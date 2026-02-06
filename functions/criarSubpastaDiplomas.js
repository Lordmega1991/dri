const functions = require("firebase-functions");
const fetch = require("node-fetch");

exports.criarPasta = functions.https.onRequest(async (req, res) => {
  // ✅ Habilita CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

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

    // 🔗 Chama o Apps Script
    const response = await fetch(
      "https://script.google.com/macros/s/AKfycbytMchg1G2gIuAbmXwDHofnsMUeIWcEgQgZp7wbEE9mNsgeP7cQeHbBeH33Okegxb_Y/exec",
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({nomePasta}),
      },
    );

    const data = await response.text(); // Apps Script retorna JSON como texto

    res.status(200).send(data);
  } catch (erro) {
    res.status(500).json({
      status: "erro",
      mensagem: erro.toString(),
    });
  }
});
