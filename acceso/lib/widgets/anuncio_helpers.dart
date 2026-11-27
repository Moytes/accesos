import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Metadatos visuales y de etiqueta para cada tipo oficial de aviso académico.
class AnuncioTipoMeta {
  final String key;
  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;

  const AnuncioTipoMeta({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
  });
}

/// Utilidades compartidas entre las vistas de profesor y alumno para avisos.
class AnuncioHelper {
  AnuncioHelper._();

  static const List<AnuncioTipoMeta> tipos = [
    AnuncioTipoMeta(
      key: 'aviso',
      label: 'Aviso general',
      shortLabel: 'Aviso',
      icon: Icons.campaign_outlined,
      color: AppColors.primary,
    ),
    AnuncioTipoMeta(
      key: 'tarea',
      label: 'Tarea / Actividad',
      shortLabel: 'Tarea',
      icon: Icons.assignment_outlined,
      color: AppColors.success,
    ),
    AnuncioTipoMeta(
      key: 'examen',
      label: 'Examen',
      shortLabel: 'Examen',
      icon: Icons.quiz_outlined,
      color: AppColors.warning,
    ),
    AnuncioTipoMeta(
      key: 'urgente',
      label: 'Urgente / Inasistencia',
      shortLabel: 'Urgente',
      icon: Icons.priority_high_rounded,
      color: AppColors.dangerRed,
    ),
  ];

  static String normalizeTipo(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized == 'falta' || normalized == 'inasistencia') {
      return 'urgente';
    }
    for (final item in tipos) {
      if (item.key == normalized) {
        return item.key;
      }
    }
    return 'aviso';
  }

  static AnuncioTipoMeta metaFor(String? raw) {
    final key = normalizeTipo(raw);
    return tipos.firstWhere(
      (item) => item.key == key,
      orElse: () => tipos.first,
    );
  }

  static bool fueEditado(Map<String, dynamic> anuncio) {
    final creadaRaw =
        (anuncio['fecha_creacion'] ?? anuncio['fechaCreacion'])?.toString();
    final updatedRaw =
        (anuncio['updated_at'] ?? anuncio['updatedAt'])?.toString();
    if (creadaRaw == null || updatedRaw == null) return false;
    try {
      final creada = DateTime.parse(creadaRaw);
      final updated = DateTime.parse(updatedRaw);
      return updated.difference(creada).inSeconds > 30;
    } catch (_) {
      return false;
    }
  }

  static String formatFechaRelativa(dynamic rawFecha) {
    final fecha = rawFecha?.toString();
    if (fecha == null || fecha.isEmpty) return '';
    try {
      final dt = DateTime.parse(fecha).toLocal();
      const meses = [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ];
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes >= 0 && diff.inMinutes < 1) return 'Hace un momento';
      if (diff.inMinutes >= 1 && diff.inMinutes < 60) {
        return 'Hace ${diff.inMinutes} min';
      }
      if (diff.inHours >= 0 && diff.inHours < 24) {
        return 'Hace ${diff.inHours} h';
      }
      return '${dt.day} ${meses[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  static String formatFechaCompleta(dynamic rawFecha) {
    final fecha = rawFecha?.toString();
    if (fecha == null || fecha.isEmpty) return '';
    try {
      final dt = DateTime.parse(fecha).toLocal();
      const meses = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} de ${meses[dt.month - 1]} ${dt.year} a las $h:$m';
    } catch (_) {
      return '';
    }
  }

  static Widget buildTipoBadge(String? raw, {bool compact = false}) {
    final meta = metaFor(raw);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: meta.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(meta.icon, size: compact ? 13 : 14, color: meta.color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                meta.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: meta.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
