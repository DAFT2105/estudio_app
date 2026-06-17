// lib/services/ai_question_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/question.dart';

/// Modelo temporal para preguntas generadas por IA
/// antes de ser guardadas en Firestore
class AIGeneratedQuestion {
  final String text;
  final QuestionType type;
  final List<String> options;
  final String correctAnswer;
  final String? explanation;
  final String? topic;
  final QuestionDifficulty difficulty;
  bool selected;

  AIGeneratedQuestion({
    required this.text,
    required this.type,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.topic,
    required this.difficulty,
    this.selected = true,
  });
}

class AIQuestionService {
  // ─────────────────────────────────────────────
  // CONFIGURACIÓN
  // ─────────────────────────────────────────────

  static String get _groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static String get _groqModel =>
      dotenv.env['GROQ_MODEL'] ?? 'llama-3.3-70b-versatile';
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get _geminiModel =>
      dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash';

  static const String _groqBaseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const int _maxQuestions = 20;

  // ─────────────────────────────────────────────
  // MÉTODO PÚBLICO — Por texto (usa Groq)
  // ─────────────────────────────────────────────

  /// Genera preguntas a partir de un tema usando Groq + Llama
  static Future<List<AIGeneratedQuestion>> generateFromText({
    required String subjectName,
    required String topic,
    required int count,
    required QuestionDifficulty difficulty,
    required QuestionType type,
  }) async {
    if (_groqApiKey.isEmpty) {
      throw AIException('Groq API key no configurada');
    }

    final clampedCount = count.clamp(1, _maxQuestions);
    final prompt = _buildTextPrompt(
      subjectName: subjectName,
      topic: topic,
      count: clampedCount,
      difficulty: difficulty,
      type: type,
    );

    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _groqModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Eres un experto en educación. Generas preguntas de examen en formato JSON estricto. Solo respondes con JSON válido, sin texto adicional, sin markdown, sin bloques de código.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 4000,
        }),
      );

      if (response.statusCode != 200) {
        throw AIException(
            'Error de Groq API: ${response.statusCode} — ${response.body}');
      }

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      return _parseQuestionsFromJSON(content, difficulty);
    } catch (e) {
      if (e is AIException) rethrow;
      throw AIException('Error al conectar con Groq: $e');
    }
  }

  // ─────────────────────────────────────────────
  // MÉTODO PÚBLICO — Por imagen (usa Gemini)
  // ─────────────────────────────────────────────

  /// Analiza imagen e identifica el tema, luego genera preguntas NUEVAS
  /// adaptadas al grado y dificultad seleccionada
  static Future<List<AIGeneratedQuestion>> generateFromImage({
    required File imageFile,
    required String subjectName,
    required int count,
    required QuestionDifficulty difficulty,
    required String gradeLevel,
  }) async {
    if (_geminiApiKey.isEmpty) {
      throw AIException('Gemini API key no configurada');
    }

    final clampedCount = count.clamp(1, _maxQuestions);
    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final mimeType = _getMimeType(imageFile.path);

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey';

    final prompt = _buildImagePrompt(
      subjectName: subjectName,
      count: clampedCount,
      difficulty: difficulty,
      gradeLevel: gradeLevel,
    );

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': mimeType,
                    'data': base64Image,
                  },
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 8192,
            'response_mime_type': 'application/json',
          },
        }),
      );

      if (response.statusCode != 200) {
        throw AIException(
            'Error de Gemini API: ${response.statusCode} — ${response.body}');
      }

      final data = jsonDecode(response.body);
      final content =
          data['candidates'][0]['content']['parts'][0]['text'] as String;
      return _parseQuestionsFromJSON(content, difficulty);
    } catch (e) {
      if (e is AIException) rethrow;
      throw AIException('Error al conectar con Gemini: $e');
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS PRIVADOS — Prompts
  // ─────────────────────────────────────────────

  static String _buildTextPrompt({
    required String subjectName,
    required String topic,
    required int count,
    required QuestionDifficulty difficulty,
    required QuestionType type,
  }) {
    final difficultyText = {
      QuestionDifficulty.easy: 'fácil (nivel básico, conceptos fundamentales)',
      QuestionDifficulty.medium:
          'media (nivel intermedio, aplicación de conceptos)',
      QuestionDifficulty.hard:
          'difícil (nivel avanzado, análisis y síntesis)',
    }[difficulty]!;

    final typeText = {
      QuestionType.multipleChoice:
          'opción múltiple con exactamente 4 alternativas (A, B, C, D)',
      QuestionType.trueFalse: 'verdadero o falso',
      QuestionType.shortAnswer: 'respuesta corta',
    }[type]!;

    return '''
Genera exactamente $count preguntas de $typeText sobre "$topic" para la materia "$subjectName".
Dificultad: $difficultyText.

Responde ÚNICAMENTE con este JSON, sin texto adicional:

{
  "preguntas": [
    {
      "texto": "¿Texto de la pregunta?",
      "tipo": "${_typeToString(type)}",
      "opciones": ["Opción A", "Opción B", "Opción C", "Opción D"],
      "respuesta_correcta": "Opción A",
      "explicacion": "Breve explicación de por qué es correcta",
      "tema": "$topic"
    }
  ]
}

Reglas importantes:
- Para opción múltiple: exactamente 4 opciones, solo una correcta
- Para verdadero/falso: opciones = ["Verdadero", "Falso"]
- Para respuesta corta: opciones = []
- La explicación debe ser breve (máximo 2 líneas)
- Genera exactamente $count preguntas
''';
  }

  static String _buildImagePrompt({
    required String subjectName,
    required int count,
    required QuestionDifficulty difficulty,
    required String gradeLevel,
  }) {
    final difficultyText = {
      QuestionDifficulty.easy: 'fácil (conceptos básicos y fundamentales)',
      QuestionDifficulty.medium:
          'media (aplicación práctica de los conceptos)',
      QuestionDifficulty.hard:
          'difícil (análisis profundo y resolución de problemas complejos)',
    }[difficulty]!;

    return '''
Analiza esta imagen educativa de la materia "$subjectName" para estudiantes de $gradeLevel.

PASO 1 — Identifica:
- ¿Qué tema o concepto educativo se está enseñando?
- ¿Qué tipo de contenido contiene? (teoría, ejemplos, ejercicios, fórmulas, diagramas)
- ¿Cuál es el nivel de los conceptos mostrados?

PASO 2 — Genera exactamente $count preguntas NUEVAS y ORIGINALES:
- NO copies las preguntas que aparecen en la imagen
- Crea ejercicios NUEVOS basados en el MISMO TEMA que identificaste
- Las preguntas deben ser apropiadas para estudiantes de $gradeLevel
- Dificultad: $difficultyText
- Si el tema incluye matemáticas o fórmulas, crea ejercicios numéricos nuevos con valores distintos
- Si el tema es conceptual, crea preguntas de comprensión y aplicación

PASO 3 — Formato de respuesta (JSON puro, sin texto adicional):

{
  "tema_identificado": "Nombre del tema detectado en la imagen",
  "preguntas": [
    {
      "texto": "Texto de la pregunta nueva",
      "tipo": "multipleChoice",
      "opciones": ["Opción A", "Opción B", "Opción C", "Opción D"],
      "respuesta_correcta": "Opción A",
      "explicacion": "Por qué esta respuesta es correcta",
      "tema": "Subtema específico"
    }
  ]
}

Reglas estrictas:
- Exactamente $count preguntas nuevas y originales
- Exactamente 4 opciones por pregunta de opción múltiple
- Solo una respuesta correcta por pregunta
- Las preguntas deben evaluar comprensión y aplicación, no memorización de la imagen
- Adapta el vocabulario al nivel $gradeLevel
''';
  }

  // ─────────────────────────────────────────────
  // HELPERS PRIVADOS — Parsing
  // ─────────────────────────────────────────────

  static List<AIGeneratedQuestion> _parseQuestionsFromJSON(
    String content,
    QuestionDifficulty defaultDifficulty,
  ) {
    try {
      String cleanContent = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final startIndex = cleanContent.indexOf('{');
      final endIndex = cleanContent.lastIndexOf('}');
      if (startIndex == -1 || endIndex == -1) {
        throw AIException('No se encontró JSON válido en la respuesta');
      }
      cleanContent = cleanContent.substring(startIndex, endIndex + 1);

      final json = jsonDecode(cleanContent) as Map<String, dynamic>;
      final preguntas = json['preguntas'] as List<dynamic>;

      return preguntas.map((p) {
        final pregunta = p as Map<String, dynamic>;
        final tipoStr = pregunta['tipo'] as String? ?? 'multipleChoice';
        final tipo = _parseType(tipoStr);
        final opciones = (pregunta['opciones'] as List<dynamic>?)
                ?.map((o) => o.toString())
                .toList() ??
            [];

        return AIGeneratedQuestion(
          text: pregunta['texto'] as String,
          type: tipo,
          options: opciones,
          correctAnswer: pregunta['respuesta_correcta'] as String,
          explanation: pregunta['explicacion'] as String?,
          topic: pregunta['tema'] as String?,
          difficulty: defaultDifficulty,
          selected: true,
        );
      }).toList();
    } catch (e) {
      if (e is AIException) rethrow;
      throw AIException('Error al procesar respuesta de IA: $e');
    }
  }

  static QuestionType _parseType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'multiplechoice':
      case 'multiple_choice':
      case 'opcion_multiple':
        return QuestionType.multipleChoice;
      case 'truefalse':
      case 'true_false':
      case 'verdaderofalso':
      case 'verdadero_falso':
        return QuestionType.trueFalse;
      case 'shortanswer':
      case 'short_answer':
      case 'respuesta_corta':
        return QuestionType.shortAnswer;
      default:
        return QuestionType.multipleChoice;
    }
  }

  static String _typeToString(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'multipleChoice';
      case QuestionType.trueFalse:
        return 'trueFalse';
      case QuestionType.shortAnswer:
        return 'shortAnswer';
    }
  }

  static String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

class AIException implements Exception {
  final String message;
  const AIException(this.message);

  @override
  String toString() => 'AIException: $message';
}