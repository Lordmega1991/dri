// lib/envio_documentos_secretaria.dart
import 'package:flutter/material.dart';
import 'upload_diplomas_page.dart';
import 'upload_documentos_page.dart';

class EnvioDocumentosSecretariaPage extends StatefulWidget {
  const EnvioDocumentosSecretariaPage({super.key});

  @override
  State<EnvioDocumentosSecretariaPage> createState() =>
      _EnvioDocumentosSecretariaPageState();
}

class _EnvioDocumentosSecretariaPageState
    extends State<EnvioDocumentosSecretariaPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Envio de Documentos - Secretaria'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecione o tipo de documento que deseja enviar:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            // Card para Upload de Documentos
            _buildDocumentCard(
              icon: Icons.upload_file_outlined,
              title: "Upload de Documentos",
              subtitle: "Enviar documentos relacionados às defesas",
              color: const Color(0xFF2196F3),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UploadDocumentosPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Card para Emissão de Diplomas
            _buildDocumentCard(
              icon: Icons.school_outlined,
              title: "Emissão de Diplomas",
              subtitle: "Enviar documentos para emissão de diploma",
              color: const Color(0xFF9C27B0),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UploadDiplomasPage()),
                );
              },
            ),

            const SizedBox(height: 16),

            // Você pode adicionar mais cards para outros tipos de documentos aqui
            _buildDocumentCard(
              icon: Icons.description_outlined,
              title: "Outros Documentos",
              subtitle: "Enviar outros documentos",
              color: const Color(0xFF4CAF50),
              onTap: () {
                // Implementar navegação para outras funcionalidades futuras
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Funcionalidade em desenvolvimento'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
