import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import 'session_service.dart';

class SessionWrapper extends StatefulWidget {
  final Widget child;

  const SessionWrapper({super.key, required this.child});

  @override
  State<SessionWrapper> createState() => _SessionWrapperState();
}

class _SessionWrapperState extends State<SessionWrapper>
    with WidgetsBindingObserver {
  final SessionService _sessionService = SessionService();
  bool _expiredDialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionService.initialize(_handleSessionExpired);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionService.recordActivity();
    }
  }

  void _handleSessionExpired() {
    if (!mounted || _expiredDialogVisible) return;
    _expiredDialogVisible = true;
    _sessionService.endSession();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Sesión Expirada',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Tu sesión ha expirado por inactividad. Por favor, inicia sesión nuevamente.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _navigateToLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _sessionService.recordActivity(),
      onPanDown: (_) => _sessionService.recordActivity(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          widget.child,
          const Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Center(
                child: OfflineStatusBanner(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
