// lib/services/ai_question_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import '../models/subject.dart';

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
  static Future<
      ({
        List<AIGeneratedQuestion> questions,
        int corrected,
        int discarded
      })> generateFromText({
    required String subjectName,
    required String topic,
    required int count,
    required QuestionDifficulty difficulty,
    required QuestionType type,
    required SubjectArea area,
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
      area: area,
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
          'max_tokens': 8000,
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
  static Future<
      ({
        List<AIGeneratedQuestion> questions,
        int corrected,
        int discarded
      })> generateFromImage({
    required File imageFile,
    required String subjectName,
    required int count,
    required QuestionDifficulty difficulty,
    required String gradeLevel,
    required SubjectArea area,
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
      area: area,
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
    required SubjectArea area,
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
${_mathVerificationBlock(area)}
Responde ÚNICAMENTE con este JSON, sin texto adicional:

{
  "preguntas": [
    {
      "texto": "¿Texto de la pregunta?",
      "tipo": "${_typeToString(type)}",
      "opciones": ["Opción A", "Opción B", "Opción C", "Opción D"],
      "valor_correcto": "Copia EXACTA de la opción correcta, idéntica a como aparece en \\"opciones\\"",
      "respuesta_correcta": "Debe ser IDÉNTICO al campo valor_correcto — no un valor distinto",
      "explicacion": "Breve explicación de por qué es correcta",
      "tema": "$topic"
    }
  ]
}

Reglas importantes:
- Para opción múltiple: exactamente 4 opciones, solo una correcta
- Para verdadero/falso: opciones = ["Verdadero", "Falso"]
- Para respuesta corta: opciones = []
- "valor_correcto" y "respuesta_correcta" DEBEN ser el mismo texto exacto — nunca uno calculado y otro distinto
- "valor_correcto" DEBE estar copiado literalmente de la lista "opciones", sin cambiar ni un carácter
- La explicación debe ser breve (máximo 2 líneas)
- Genera exactamente $count preguntas
''';
  }

  /// Instrucción extra que se inyecta SOLO para materias del área
  /// Matemática — pide a la IA verificar su propia aritmética paso a paso
  /// antes de responder, para reducir errores de cálculo.
  static String _mathVerificationBlock(SubjectArea area) {
    if (area != SubjectArea.matematica) return '';
    return '''

⚠️ VERIFICACIÓN OBLIGATORIA (materia de Matemática) — sigue este orden exacto:
1. Resuelve el ejercicio TÚ MISMO paso a paso, mostrando el cálculo completo.
2. Anota el resultado final numérico que obtuviste.
3. Construye las 4 opciones de modo que UNA de ellas sea exactamente ese resultado (las otras 3 deben ser distractores plausibles, no el resultado correcto).
4. Copia ese resultado, EXACTO y sin cambiar nada, en los campos "valor_correcto" Y "respuesta_correcta".
- NO generes primero las opciones al azar y luego "ajustes" la respuesta — el orden es: calcular → recién ahí elegir cuál opción es la correcta.
- En el campo "explicacion", resume el cálculo en MÁXIMO 3 líneas cortas (esto reemplaza la regla general de 2 líneas, solo para esta materia) — prioriza mostrar los números clave del cálculo, no expliques con prosa larga.
- Revisa la operación una segunda vez antes de responder — los errores aritméticos no son aceptables.
''';
  }

  static String _buildImagePrompt({
    required String subjectName,
    required int count,
    required QuestionDifficulty difficulty,
    required String gradeLevel,
    required SubjectArea area,
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
${_mathVerificationBlock(area)}
PASO 3 — Formato de respuesta (JSON puro, sin texto adicional):

{
  "tema_identificado": "Nombre del tema detectado en la imagen",
  "preguntas": [
    {
      "texto": "Texto de la pregunta nueva",
      "tipo": "multipleChoice",
      "opciones": ["Opción A", "Opción B", "Opción C", "Opción D"],
      "valor_correcto": "Copia EXACTA de la opción correcta, idéntica a como aparece en \\"opciones\\"",
      "respuesta_correcta": "Debe ser IDÉNTICO al campo valor_correcto — no un valor distinto",
      "explicacion": "Por qué esta respuesta es correcta",
      "tema": "Subtema específico"
    }
  ]
}

Reglas estrictas:
- Exactamente $count preguntas nuevas y originales
- Exactamente 4 opciones por pregunta de opción múltiple
- Solo una respuesta correcta por pregunta
- "valor_correcto" y "respuesta_correcta" DEBEN ser el mismo texto exacto, copiado literalmente de "opciones"
- Las preguntas deben evaluar comprensión y aplicación, no memorización de la imagen
- Adapta el vocabulario al nivel $gradeLevel
''';
  }

  // ─────────────────────────────────────────────
  // HELPERS PRIVADOS — Parsing
  // ─────────────────────────────────────────────

  /// Devuelve las preguntas válidas + cuántas se corrigieron automáticamente
  /// (la IA calculó bien pero etiquetó mal la opción correcta) y cuántas se
  /// descartaron (ni el valor calculado ni la respuesta marcada existen
  /// entre las opciones — imposible de corregir sin inventar datos).
  static ({
    List<AIGeneratedQuestion> questions,
    int corrected,
    int discarded
  }) _parseQuestionsFromJSON(
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

      final validQuestions = <AIGeneratedQuestion>[];
      int corrected = 0;
      int discarded = 0;

      for (final p in preguntas) {
        final pregunta = p as Map<String, dynamic>;
        final textoPregunta = pregunta['texto'] as String?;
        if (textoPregunta == null) {
          discarded++;
          continue;
        }

        final tipoStr = pregunta['tipo'] as String? ?? 'multipleChoice';
        final tipo = _parseType(tipoStr);
        final opciones = (pregunta['opciones'] as List<dynamic>?)
                ?.map((o) => o.toString())
                .toList() ??
            [];

        var respuestaCorrecta = pregunta['respuesta_correcta'] as String? ?? '';
        final valorCorrecto = pregunta['valor_correcto'] as String?;

        // Solo verificamos contra "opciones" cuando realmente las hay
        // (multipleChoice/trueFalse) — respuesta_corta no tiene opciones.
        if (opciones.isNotEmpty) {
          String? matchInOptions(String? value) {
            if (value == null) return null;
            final normalized = value.trim().toLowerCase();
            for (final o in opciones) {
              if (o.trim().toLowerCase() == normalized) return o;
            }
            return null;
          }

          final matchFromValorCorrecto = matchInOptions(valorCorrecto);
          final matchFromRespuesta = matchInOptions(respuestaCorrecta);

          if (matchFromValorCorrecto != null) {
            // valor_correcto (el resultado del cálculo) SÍ está entre las
            // opciones — confiamos en él por encima de respuesta_correcta,
            // ya que es el que viene directo del cómputo paso a paso.
            if (matchFromRespuesta != matchFromValorCorrecto) {
              corrected++;
            }
            respuestaCorrecta = matchFromValorCorrecto;
          } else if (matchFromRespuesta != null) {
            // No hay valor_correcto usable, pero respuesta_correcta sí
            // coincide con alguna opción — la dejamos tal cual.
            respuestaCorrecta = matchFromRespuesta;
          } else {
            // Ninguno de los dos coincide con ninguna opción — no hay
            // forma confiable de corregir esto sin inventar datos.
            discarded++;
            continue;
          }
        }

        validQuestions.add(AIGeneratedQuestion(
          text: textoPregunta,
          type: tipo,
          options: opciones,
          correctAnswer: respuestaCorrecta,
          explanation: pregunta['explicacion'] as String?,
          topic: pregunta['tema'] as String?,
          difficulty: defaultDifficulty,
          selected: true,
        ));
      }

      return (
        questions: validQuestions,
        corrected: corrected,
        discarded: discarded
      );
    } catch (e) {
      if (e is AIException) rethrow;
      if (e is FormatException) {
        throw AIException(
            'La respuesta de la IA se cortó antes de terminar (probablemente por pedir demasiadas preguntas o explicaciones muy largas). '
            'Intenta de nuevo con menos preguntas o una dificultad más simple.');
      }
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