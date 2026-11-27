import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';

class PickedAttachment {
  final List<int> bytes;
  final String fileName;
  final String mimeType;
  final bool isPdf;

  const PickedAttachment({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.isPdf,
  });
}

/// Gestión centralizada de permisos en tiempo de ejecución (Cámara, Galería y Archivos)
/// con retroalimentación clara al usuario y validación de archivos.
class AppPermissionsService {
  AppPermissionsService._();

  static final ImagePicker _picker = ImagePicker();

  static const int maxEvidenceBytes = 12 * 1024 * 1024;
  static const int maxAvatarBytes = 5 * 1024 * 1024;

  static Future<bool> ensureCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) return true;

    if (context.mounted) {
      await _showPermissionRationaleDialog(
        context,
        title: 'Permiso de Cámara requerido',
        message: result.isPermanentlyDenied
            ? 'Control+ necesita acceso a la cámara para tomar fotografías de evidencias o tu foto de perfil. Habilítalo en los Ajustes de la aplicación.'
            : 'Sin permiso de cámara no es posible capturar fotografías desde la app.',
        openSettings: result.isPermanentlyDenied,
      );
    }
    return false;
  }

  static Future<bool> ensureGalleryOrFilesPermission(
    BuildContext context, {
    bool forDocuments = false,
  }) async {
    if (Platform.isIOS) {
      if (forDocuments) return true; // UIDocumentPicker no requiere permiso global
      final status = await Permission.photos.status;
      if (status.isGranted || status.isLimited) return true;
      final req = await Permission.photos.request();
      if (req.isGranted || req.isLimited) return true;
      if (context.mounted) {
        await _showPermissionRationaleDialog(
          context,
          title: 'Permiso de Fotos requerido',
          message: req.isPermanentlyDenied
              ? 'Control+ requiere acceso a tu galería para seleccionar imágenes. Habilítalo desde Ajustes.'
              : 'Necesitamos permiso para abrir tus imágenes.',
          openSettings: req.isPermanentlyDenied,
        );
      }
      return false;
    }

    if (Platform.isAndroid) {
      PermissionStatus photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted || photosStatus.isLimited) return true;

      photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted || photosStatus.isLimited) return true;

      // Fallback para Android <= 12 (API <= 32)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;

      final storageReq = await Permission.storage.request();
      if (storageReq.isGranted) return true;

      // Android 11+ Photo Picker / SAF siguen funcionando sin permiso amplio en varios dispositivos,
      // pero si el usuario denegó permanentemente avisamos claramente.
      if (photosStatus.isPermanentlyDenied &&
          storageReq.isPermanentlyDenied &&
          context.mounted) {
        await _showPermissionRationaleDialog(
          context,
          title: forDocuments
              ? 'Permiso de Archivos requerido'
              : 'Permiso de Imágenes requerido',
          message:
              'Control+ necesita acceso a tus archivos o galería para adjuntar documentos e imágenes. Puedes habilitarlo en Ajustes.',
          openSettings: true,
        );
        return false;
      }

      if (forDocuments) return true;
      return false;
    }

    return true;
  }

  static Future<void> _showPermissionRationaleDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool openSettings,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          if (openSettings)
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Abrir Ajustes'),
            ),
        ],
      ),
    );
  }

  static Future<PickedAttachment?> pickPhotoFromCamera(
    BuildContext context, {
    int maxBytes = maxEvidenceBytes,
    int imageQuality = 80,
  }) async {
    final allowed = await ensureCameraPermission(context);
    if (!allowed) return null;

    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
    );
    if (photo == null) return null;

    final bytes = await photo.readAsBytes();
    final validated = _validateAttachment(
      context,
      bytes: bytes,
      fileName: photo.name.isNotEmpty ? photo.name : 'foto_camara.jpg',
      maxBytes: maxBytes,
      allowPdf: false,
    );
    return validated;
  }

  static Future<List<PickedAttachment>> pickImagesFromGallery(
    BuildContext context, {
    bool allowMultiple = true,
    int maxBytes = maxEvidenceBytes,
    int imageQuality = 80,
  }) async {
    final allowed = await ensureGalleryOrFilesPermission(context);
    if (!allowed) return [];

    final List<XFile> picked = allowMultiple
        ? await _picker.pickMultiImage(imageQuality: imageQuality)
        : [
            if (await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: imageQuality,
                )
                case final single?)
              single,
          ];

    final out = <PickedAttachment>[];
    for (int i = 0; i < picked.length; i++) {
      final xf = picked[i];
      final bytes = await xf.readAsBytes();
      final name = xf.name.isNotEmpty ? xf.name : 'imagen_$i.jpg';
      if (!context.mounted) break;
      final valid = _validateAttachment(
        context,
        bytes: bytes,
        fileName: name,
        maxBytes: maxBytes,
        allowPdf: false,
      );
      if (valid != null) out.add(valid);
    }
    return out;
  }

  static Future<PickedAttachment?> pickPdfDocument(
    BuildContext context, {
    int maxBytes = maxEvidenceBytes,
  }) async {
    final allowed = await ensureGalleryOrFilesPermission(
      context,
      forDocuments: true,
    );
    if (!allowed) return null;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final pf = result.files.first;
    List<int>? bytes = pf.bytes;
    if (bytes == null && pf.path != null) {
      bytes = await File(pf.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) return null;

    if (!context.mounted) return null;
    return _validateAttachment(
      context,
      bytes: bytes,
      fileName: pf.name.isNotEmpty ? pf.name : 'documento.pdf',
      maxBytes: maxBytes,
      allowPdf: true,
    );
  }

  /// Muestra un selector modal unificado (Cámara, Galería, PDF) solicitando permisos.
  static Future<List<PickedAttachment>> showAttachmentPickerSheet(
    BuildContext context, {
    bool allowPdf = true,
    bool allowMultiple = true,
    int maxBytes = maxEvidenceBytes,
    String title = 'Adjuntar evidencia',
  }) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryDark.withOpacity(0.1),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primaryDark,
                  ),
                ),
                title: const Text('Tomar fotografía'),
                subtitle: const Text('Usar la cámara del dispositivo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accentBlue.withOpacity(0.1),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.accentBlue,
                  ),
                ),
                title: Text(
                  allowMultiple
                      ? 'Elegir de la galería'
                      : 'Elegir imagen de galería',
                ),
                subtitle: const Text('Formatos JPG, PNG o WEBP'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (allowPdf)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.danger.withOpacity(0.1),
                    child: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.danger,
                    ),
                  ),
                  title: const Text('Seleccionar documento PDF'),
                  subtitle: const Text('Recetas médicas o comprobantes (máx. 12 MB)'),
                  onTap: () => Navigator.pop(ctx, 'pdf'),
                ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !context.mounted) return [];

    switch (choice) {
      case 'camera':
        final item = await pickPhotoFromCamera(context, maxBytes: maxBytes);
        return item != null ? [item] : [];
      case 'gallery':
        return pickImagesFromGallery(
          context,
          allowMultiple: allowMultiple,
          maxBytes: maxBytes,
        );
      case 'pdf':
        final doc = await pickPdfDocument(context, maxBytes: maxBytes);
        return doc != null ? [doc] : [];
      default:
        return [];
    }
  }

  static PickedAttachment? _validateAttachment(
    BuildContext context, {
    required List<int> bytes,
    required String fileName,
    required int maxBytes,
    required bool allowPdf,
  }) {
    if (bytes.isEmpty) return null;

    if (bytes.length > maxBytes) {
      final maxMb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El archivo "$fileName" supera el límite de $maxMb MB.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return null;
    }

    final lower = fileName.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final isValidImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');

    if (isPdf && !allowPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se permiten imágenes en este apartado.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return null;
    }

    if (!isPdf && !isValidImage) {
      // Fallback seguro como jpg si viene sin extensión desde la cámara
      return PickedAttachment(
        bytes: bytes,
        fileName: '$fileName.jpg',
        mimeType: 'image/jpeg',
        isPdf: false,
      );
    }

    final mimeType = isPdf
        ? 'application/pdf'
        : lower.endsWith('.png')
            ? 'image/png'
            : lower.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';

    return PickedAttachment(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      isPdf: isPdf,
    );
  }
}
