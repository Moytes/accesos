import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../service/connectivity_service.dart';
import '../service/offline_sync_queue_service.dart';
import '../theme/app_colors.dart';

/// Imagen remota tolerante a modo offline con caché en disco y fallback degradado.
class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;
  final ColorFilter? colorFilter;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
    this.colorFilter,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = (url ?? '').trim();
    if (cleanUrl.isEmpty ||
        (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://'))) {
      return fallback ?? _defaultGradient();
    }

    return CachedNetworkImage(
      imageUrl: cleanUrl,
      width: width,
      height: height,
      fit: fit,
      imageBuilder: colorFilter != null
          ? (ctx, provider) => Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: provider,
                    fit: fit,
                    colorFilter: colorFilter,
                  ),
                ),
              )
          : null,
      placeholder: (_, __) => fallback ?? _defaultGradient(),
      errorWidget: (_, __, ___) => fallback ?? _defaultGradient(),
    );
  }

  Widget _defaultGradient() {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
    );
  }
}

/// Banner institucional de cabecera que funciona 100% offline usando caché local.
class SafeHeaderBanner extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final List<Color> gradientColors;

  const SafeHeaderBanner({
    super.key,
    this.imageUrl,
    this.height = 280,
    this.gradientColors = const [
      Color(0xCC003366),
      Color(0x66003366),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeNetworkImage(
            url: imageUrl,
            height: height,
            width: double.infinity,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
            fallback: Container(
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
            ),
          ),
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradientColors,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador flotante discreto cuando el dispositivo está offline o tiene acciones por sincronizar.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = ConnectivityService();
    final queue = OfflineSyncQueueService();

    return ValueListenableBuilder<bool>(
      valueListenable: connectivity.isOnline,
      builder: (context, online, _) {
        return ValueListenableBuilder<int>(
          valueListenable: queue.pendingCount,
          builder: (context, pending, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: queue.isSyncing,
              builder: (context, syncing, _) {
                if (online && pending == 0 && !syncing) {
                  return const SizedBox.shrink();
                }

                final bgColor = !online
                    ? const Color(0xFF37474F)
                    : AppColors.primary;
                final icon = !online
                    ? Icons.cloud_off_rounded
                    : syncing
                        ? Icons.sync
                        : Icons.cloud_upload_outlined;

                String text;
                if (!online && pending > 0) {
                  text = 'Sin conexión • $pending cambio(s) en cola';
                } else if (!online) {
                  text = 'Modo sin conexión • Mostrando datos guardados';
                } else if (syncing) {
                  text = 'Sincronizando $pending cambio(s)...';
                } else {
                  text = '$pending cambio(s) listos para sincronizar';
                }

                return Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (pending > 0 && !syncing) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              await connectivity.checkBackendReachability();
                              if (connectivity.isOnline.value) {
                                await queue.processQueue();
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'Sincronizar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Visualiza evidencias remotas de R2 (imágenes con zoom o enlaces PDF).
class EvidencePreviewStrip extends StatelessWidget {
  final String rawUrlsCsv;

  const EvidencePreviewStrip({
    super.key,
    required this.rawUrlsCsv,
  });

  static List<String> parseUrls(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static bool isPdfUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final urls = parseUrls(rawUrlsCsv);
    if (urls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        shrinkWrap: true,
        itemCount: urls.length,
        itemBuilder: (context, index) {
          final url = urls[index];
          final isPdf = isPdfUrl(url);

          return GestureDetector(
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: isPdf ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: isPdf
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.picture_as_pdf,
                                color: AppColors.danger,
                                size: 54,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Documento PDF adjunto',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                url,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            InteractiveViewer(
                              child: CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const SizedBox(
                                  height: 260,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const SizedBox(
                                  height: 240,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 72,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: isPdf ? AppColors.surfaceSoftBlue : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: isPdf
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            color: AppColors.danger,
                            size: 32,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
