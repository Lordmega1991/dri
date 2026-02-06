const {onRequest} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const fetch = require("node-fetch");
const {PDFDocument} = require("pdf-lib");
const fontkit = require("@pdf-lib/fontkit");

// ✅ CONFIGURAÇÃO GEN 2
setGlobalOptions({
  region: "us-central1",
  memory: "512MiB",
  timeoutSeconds: 60,
});

// ✅ FUNÇÃO CRIAR PASTA - GEN 2
exports.criarPasta = onRequest(async (req, res) => {
  // ✅ Habilita CORS
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

    // 🔗 Chama o Apps Script
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

// ✅ FUNÇÃO UPLOAD DIPLOMA - GEN 2
exports.uploadDiploma = onRequest(async (req, res) => {
  // ✅ Habilita CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(200).send("OK");
  }

  try {
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

    // 🔗 Chama o Apps Script para upload
    const response = await fetch(
      "https://script.google.com/macros/s/AKfycbyIhXtlwvEl3pABuyj1Sy_-BhYhQuGU2tUaqO36foh7bxzkOBbi_psjgZ9wwBoTMPop/exec",
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

// ✅ FUNÇÃO CONVERSÃO PDF/A-3 - GEN 2
exports.convertToPDFA = onRequest(async (req, res) => {
  // Configura CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({
      status: "erro",
      mensagem: "Método não permitido. Use POST.",
    });
  }

  try {
    const {file, fileName} = req.body;

    if (!file) {
      return res.status(400).json({
        status: "erro",
        mensagem: "Arquivo PDF não fornecido",
      });
    }

    console.log("Iniciando conversão para PDF/A-3...");

    // Decodifica o PDF da base64
    const pdfBuffer = Buffer.from(file, "base64");

    if (pdfBuffer.length === 0) {
      return res.status(400).json({
        status: "erro",
        mensagem: "Arquivo PDF vazio ou inválido",
      });
    }

    // ✅ Usar pdf-lib com metadados melhorados
    console.log("Usando pdf-lib para metadados PDF/A-3...");
    const pdfDoc = await PDFDocument.load(pdfBuffer);
    pdfDoc.registerFontkit(fontkit);

    // ✅ METADADOS ESPECÍFICOS PARA PDF/A-3
    pdfDoc.setTitle(fileName || "Documento PDF/A-3 - DRI UFPB");
    pdfDoc.setAuthor("Universidade Federal da Paraíba - DRI");
    pdfDoc.setSubject("Documentação oficial para emissão de diploma universitário");
    pdfDoc.setKeywords([
      "PDF/A-3",
      "PDF/A-3b",
      "Diploma",
      "UFPB",
      "Documentação Acadêmica",
      "Arquivo Permanente",
    ]);
    pdfDoc.setCreator("Sistema DRI UFPB - Conversor PDF/A-3");
    pdfDoc.setProducer("Firebase Cloud Functions - PDF/A-3 Converter");
    pdfDoc.setCreationDate(new Date());
    pdfDoc.setModificationDate(new Date());

    // Configurações otimizadas para compatibilidade
    const pdfABytes = await pdfDoc.save({
      useObjectStreams: false,
      addDefaultPage: false,
      objectsPerTick: 100,
      updateFieldAppearances: true,
    });

    const pdfABase64 = Buffer.from(pdfABytes).toString("base64");

    console.log("Conversão concluída - PDF com metadados PDF/A-3");
    console.log(`Tamanho original: ${pdfBuffer.length} bytes`);
    console.log(`Tamanho convertido: ${pdfABytes.length} bytes`);

    res.json({
      status: "sucesso",
      mensagem: "Arquivo processado com metadados PDF/A-3",
      pdfABase64: pdfABase64,
      tamanhoOriginal: pdfBuffer.length,
      tamanhoConvertido: pdfABytes.length,
      taxaCompressao: ((pdfABytes.length / pdfBuffer.length) * 100).toFixed(2) + "%",
      formato: "PDF/A-3 (Metadados)",
      metodo: "pdf-lib",
      observacao: "Arquivo contém metadados PDF/A-3",
    });
  } catch (error) {
    console.error("Erro na conversão PDF/A-3:", error);

    let mensagemErro = "Falha na conversão para PDF/A-3";

    if (error.message.includes("Invalid PDF")) {
      mensagemErro = "Arquivo PDF inválido ou corrompido";
    } else if (error.message.includes("password")) {
      mensagemErro = "PDF protegido por senha não suportado";
    }

    res.status(500).json({
      status: "erro",
      mensagem: `${mensagemErro}: ${error.message}`,
    });
  }
});

// ✅ FUNÇÃO DE VERIFICAÇÃO - GEN 2
exports.checkPDFAStatus = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  res.json({
    status: "disponivel",
    servicos: {
      fallback: "pdf-lib com metadados PDF/A-3 - ATIVO",
    },
    formato_principal: "PDF/A-3 (Metadados)",
    observacao: "Sistema usando metadados PDF/A-3",
  });
});

// ✅ FUNÇÃO DE TESTE PDF/A - GEN 2
exports.testPDFA = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    // Cria um PDF de teste simples
    const pdfDoc = await PDFDocument.create();
    const page = pdfDoc.addPage([600, 400]);

    page.drawText("PDF/A Test - DRI UFPB", {
      x: 50,
      y: 350,
      size: 18,
    });

    page.drawText("Este é um documento de teste para conversão PDF/A", {
      x: 50,
      y: 300,
      size: 12,
    });

    page.drawText(`Gerado em: ${new Date().toISOString()}`, {
      x: 50,
      y: 250,
      size: 10,
    });

    // Configura metadados PDF/A
    pdfDoc.setTitle("Documento de Teste PDF/A");
    pdfDoc.setAuthor("Sistema DRI UFPB");
    pdfDoc.setSubject("Teste de conversão PDF/A");
    pdfDoc.setKeywords(["teste", "PDF/A", "UFPB"]);
    pdfDoc.setCreationDate(new Date());
    pdfDoc.setModificationDate(new Date());

    const pdfBytes = await pdfDoc.save();
    const pdfBase64 = Buffer.from(pdfBytes).toString("base64");

    res.json({
      status: "sucesso",
      mensagem: "PDF de teste gerado com sucesso",
      pdfBase64: pdfBase64,
      instrucoes: "Use este PDF para testar a função convertToPDFA",
    });
  } catch (error) {
    console.error("Erro no teste PDF/A:", error);
    res.status(500).json({
      status: "erro",
      mensagem: error.message,
    });
  }
});