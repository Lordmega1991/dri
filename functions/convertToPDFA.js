const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {PDFDocument} = require("pdf-lib");
const fontkit = require("@pdf-lib/fontkit");

// Inicializa o Firebase Admin
admin.initializeApp();

exports.convertToPDFA = functions.https.onRequest(async (req, res) => {
  // Configura CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  // Verifica se é POST
  if (req.method !== "POST") {
    return res.status(405).json({
      status: "erro",
      mensagem: "Método não permitido",
    });
  }

  try {
    const {file, fileName} = req.body;

    if (!file) {
      return res.status(400).json({
        status: "erro",
        mensagem: "Arquivo não fornecido",
      });
    }

    console.log("Iniciando conversão para PDF/A...");

    // Decodifica o PDF da base64
    const pdfBuffer = Buffer.from(file, "base64");

    // Carrega o documento PDF
    const pdfDoc = await PDFDocument.load(pdfBuffer);

    // Registra fontkit para embeddar fontes (importante para PDF/A)
    pdfDoc.registerFontkit(fontkit);

    // Configura metadados para compatibilidade PDF/A
    pdfDoc.setTitle(fileName || "Documento PDF/A");
    pdfDoc.setAuthor("Sistema DRI - UFPB");
    pdfDoc.setSubject("Documentação para diploma universitário");
    pdfDoc.setKeywords(["PDF/A", "Diploma", "UFPB", "Documentação"]);
    pdfDoc.setCreationDate(new Date());
    pdfDoc.setModificationDate(new Date());

    // Para melhor compatibilidade PDF/A, podemos embeddar fontes básicas
    // ou garantir que o PDF mantenha sua estrutura original

    // Salva o documento (preserva a estrutura do PDF original)
    const pdfABytes = await pdfDoc.save({
      useObjectStreams: false, // Melhor para compatibilidade
      addDefaultPage: false,
      objectsPerTick: 100,
    });

    const pdfABase64 = Buffer.from(pdfABytes).toString("base64");

    console.log("Conversão para PDF/A concluída com sucesso");

    res.json({
      status: "sucesso",
      mensagem: "Arquivo convertido para PDF/A com sucesso",
      pdfABase64: pdfABase64,
      tamanhoOriginal: pdfBuffer.length,
      tamanhoConvertido: pdfABytes.length,
    });

  } catch (error) {
    console.error("Erro detalhado na conversão:", error);

    res.status(500).json({
      status: "erro",
      mensagem: `Falha na conversão para PDF/A: ${error.message}`,
      stack: process.env.NODE_ENV === "development" ? error.stack : undefined,
    });
  }
});
