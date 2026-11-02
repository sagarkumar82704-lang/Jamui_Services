import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../favourites/data/services/customer_favourites_service.dart';

class FavouriteButton extends StatefulWidget {
  final String providerId;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool showContainer;
  final VoidCallback? onToggle;

  const FavouriteButton({
    super.key,
    required this.providerId,
    this.size = 22,
    this.activeColor = const Color(0xFFEF4444),
    this.inactiveColor = const Color(0xFF94A3B8),
    this.showContainer = false,
    this.onToggle,
  });

  @override
  State<FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<FavouriteButton> with SingleTickerProviderStateMixin {
  final CustomerFavouritesService _favouritesService = CustomerFavouritesService();
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleToggle(bool isCurrentlyFav) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('पसंदीदा में जोड़ने के लिए कृपया पहले लॉगिन करें'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final nextState = !isCurrentlyFav;
    if (nextState) {
      _animController.forward().then((_) => _animController.reverse());
    }

    try {
      await _favouritesService.toggleFavourite(
        customerId: user.uid,
        providerId: widget.providerId,
        makeFavourite: nextState,
      );
      widget.onToggle?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('त्रुटि: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) {
      return _buildHeartIcon(isFav: false);
    }

    _favouritesService.ensureSubscribed(user.uid);

    return ValueListenableBuilder<Set<String>>(
      valueListenable: _favouritesService.favouritesNotifier,
      builder: (context, favIds, _) {
        final isFav = favIds.contains(widget.providerId);
        return _buildHeartIcon(isFav: isFav);
      },
    );
  }

  Widget _buildHeartIcon({required bool isFav}) {
    final iconWidget = ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(
        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: widget.size,
        color: isFav ? widget.activeColor : widget.inactiveColor,
      ),
    );

    if (widget.showContainer) {
      return GestureDetector(
        onTap: () => _handleToggle(isFav),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: iconWidget,
        ),
      );
    }

    return IconButton(
      icon: iconWidget,
      iconSize: widget.size,
      tooltip: isFav ? 'पसंदीदा से हटाएं' : 'पसंदीदा में जोड़ें',
      onPressed: () => _handleToggle(isFav),
    );
  }
}
