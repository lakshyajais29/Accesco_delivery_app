import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/thrift_model.dart';
import '../../services/image_upload_service.dart';
import '../../services/thrift_api_service.dart';
import '../../widgets/ds/ds.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SELL AN ITEM — list a piece on the thrift marketplace.
//
//  Figma's "Sell an Item" frame (490:1057) is a layout stub: it carries the
//  screen's chrome but none of the form itself. Rather than stopping, this is
//  interpolated from the established design language — the same grouped cards,
//  chips, inputs and ink CTA used by Profile and Product Detail — so the flow
//  is complete and consistent. When the design is finished, the structure here
//  maps one-to-one onto it.
//
//  Three steps, matching how a seller actually thinks:
//    1. Photos     — what it looks like
//    2. Details    — what it is
//    3. Pricing    — what it's worth
// ─────────────────────────────────────────────────────────────────────────────

/// The two phases of publishing, so the overlay can say which is running
/// rather than showing one undifferentiated spinner.
enum _SubmitStage { idle, uploading, publishing }

class SellItemScreen extends StatefulWidget {
  const SellItemScreen({super.key});

  static Route<void> route() => PageRouteBuilder(
    pageBuilder: (_, __, ___) => const SellItemScreen(),
    transitionDuration: AppMotion.slow,
    reverseTransitionDuration: AppMotion.normal,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
      child: child,
    ),
  );

  @override
  State<SellItemScreen> createState() => _SellItemScreenState();
}

class _SellItemScreenState extends State<SellItemScreen> {
  static const _totalSteps = 3;
  static const _kMaxPhotos = 6;
  static const _conditions = ['Like New', 'Gently Used', 'Vintage Find'];
  static const _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'One Size'];
  static const _categories = [
    'Dresses',
    'Blazers',
    'Tops',
    'Denim',
    'Ethnic',
    'Footwear',
    'Accessories',
  ];

  int _step = 0;

  final _titleController = TextEditingController();
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Photos the seller has captured or chosen, in cover-first order.
  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  int get _photoCount => _photos.length;

  String? _category;
  String? _size;
  String? _condition;

  bool _isSubmitting = false;
  String _error = '';

  /// Which half of submission is running, so the overlay can name it.
  _SubmitStage _stage = _SubmitStage.idle;
  UploadProgress? _uploadProgress;

  /// Supporting line under the overlay title — "2 of 5 · 40%" while photos
  /// upload, then a plain reassurance while the listing saves.
  String? get _overlayMessage {
    if (_stage == _SubmitStage.publishing) return 'Almost there';
    final progress = _uploadProgress;
    if (progress == null) return 'Preparing your photos';
    return '${progress.currentIndex} of ${progress.total}'
        ' · ${progress.percent}%';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Offers camera or gallery, then appends the chosen photo.
  ///
  /// Images are captured at a capped resolution and quality: a modern phone
  /// camera produces 4–8 MB files, which would make the listing upload slow
  /// and the thumbnails wasteful. 1600px at 80% is well beyond what any
  /// product card or detail hero needs.
  Future<void> _addPhoto() async {
    if (_photos.length >= _kMaxPhotos) return;
    HapticFeedback.selectionClick();

    final source = await showAppSheet<ImageSource>(
      context,
      child: AppSheet(
        title: 'Add a Photo',
        subtitle: 'Natural light shows colour and condition best',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.page(context),
              ),
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppPalette.accentDeep,
              ),
              title: Text(
                'Take a photo',
                style: AppType.bodyLarge.copyWith(
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
            ListTile(
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.page(context),
              ),
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppPalette.accentDeep,
              ),
              title: Text(
                'Choose from gallery',
                style: AppType.bodyLarge.copyWith(
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _photos.add(picked);
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      // Thrown when the OS denies camera/photo permission, and on simulators
      // with no camera available.
      AppSnack.error(
        context,
        source == ImageSource.camera
            ? 'Camera unavailable. Check permissions in Settings.'
            : 'Could not open your photos. Check permissions in Settings.',
      );
    }
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_photoCount == 0) {
          setState(() => _error = 'Add at least one photo of your piece.');
          return false;
        }
        return true;
      case 1:
        if (_titleController.text.trim().isEmpty) {
          setState(() => _error = 'Give your listing a title.');
          return false;
        }
        if (_category == null) {
          setState(() => _error = 'Pick a category.');
          return false;
        }
        if (_size == null) {
          setState(() => _error = 'Pick a size.');
          return false;
        }
        if (_condition == null) {
          setState(() => _error = 'Choose the condition.');
          return false;
        }
        return true;
      case 2:
        final price = int.tryParse(_priceController.text.trim());
        if (price == null || price <= 0) {
          setState(() => _error = 'Enter a valid asking price.');
          return false;
        }
        final original = int.tryParse(_originalPriceController.text.trim());
        // A "was" price below the asking price would render as a negative
        // discount on the product card.
        if (original != null && original <= price) {
          setState(
            () => _error = 'Original price should be higher than your price.',
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < _totalSteps - 1) {
      setState(() {
        _step++;
        _error = '';
      });
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _step--;
      _error = '';
    });
  }

  Future<void> _submit() async {
    // Guard against a double submit even if a tap slips past the overlay.
    if (_isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Please sign in before listing an item.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = '';
      _uploadProgress = null;
      _stage = _SubmitStage.uploading;
    });

    final price = int.parse(_priceController.text.trim());
    final original = int.tryParse(_originalPriceController.text.trim());

    try {
      // 1. Photos to Cloud Storage. The listing must never be created with
      //    local paths — those are meaningless to every other device.
      final imageUrls = await ImageUploadService.instance.uploadListingImages(
        _photos,
        sellerId: user.uid,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );

      if (!mounted) return;
      setState(() => _stage = _SubmitStage.publishing);

      // 2. Listing to the API, carrying the real download URLs.
      final draft = ThriftListingDraft(
        sellerId: user.uid,
        sellerName: user.displayName,
        title: _titleController.text.trim(),
        brand: _brandController.text.trim(),
        category: _category,
        description: _descriptionController.text.trim(),
        size: _size ?? 'One Size',
        condition: _conditionFromLabel(_condition),
        // The form collects rupees; the API stores paise.
        priceInPaise: price * 100,
        originalPriceInPaise: original == null ? null : original * 100,
        imageUrls: imageUrls,
      );

      final listing = await ThriftApiService.instance.createListing(draft);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              _ListingSubmittedScreen(title: listing.title),
          transitionDuration: AppMotion.normal,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } on ImageUploadException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _stage = _SubmitStage.idle;
        _error = error.message;
      });
    } on ThriftApiException catch (error) {
      if (!mounted) return;
      // The photos uploaded but the listing didn't save. They are orphaned in
      // Storage; a retry re-uploads into a fresh batch folder rather than
      // reusing them, which is the safe trade — a stale URL on a listing would
      // be worse than a few unreferenced objects for a cleanup job to sweep.
      setState(() {
        _isSubmitting = false;
        _stage = _SubmitStage.idle;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _stage = _SubmitStage.idle;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  /// Maps the chip label back onto the wire enum.
  ThriftCondition _conditionFromLabel(String? label) => switch (label) {
    'Like New' => ThriftCondition.likeNew,
    'Vintage Find' => ThriftCondition.vintageFind,
    _ => ThriftCondition.gentlyUsed,
  };

  @override
  Widget build(BuildContext context) {
    final inset = AppSpacing.page(context);
    final isLast = _step == _totalSteps - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: AppProgressOverlay(
        isVisible: _stage != _SubmitStage.idle,
        title: _stage == _SubmitStage.publishing
            ? 'Publishing listing'
            : 'Uploading photos',
        message: _overlayMessage,
        progress: _stage == _SubmitStage.uploading
            ? _uploadProgress?.fraction
            : null,
        child: Scaffold(
          backgroundColor: AppPalette.canvas,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header + progress ────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset - AppSpacing.xs,
                    AppSpacing.xs,
                    inset,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: Icons.arrow_back,
                        onPressed: _isSubmitting ? null : _back,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'List an Item',
                          style: AppType.displaySmall.copyWith(fontSize: 20),
                        ),
                      ),
                      Text('${_step + 1}/$_totalSteps', style: AppType.mono),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: Row(
                    children: [
                      for (var i = 0; i < _totalSteps; i++) ...[
                        Expanded(
                          child: AnimatedContainer(
                            duration: AppMotion.normal,
                            curve: AppMotion.standard,
                            height: 3,
                            decoration: BoxDecoration(
                              color: i <= _step
                                  ? AppPalette.accent
                                  : AppPalette.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (i < _totalSteps - 1)
                          const SizedBox(width: AppSpacing.xxs),
                      ],
                    ],
                  ),
                ),

                // ── Step body ────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      AppSpacing.xl,
                      inset,
                      AppSpacing.xl,
                    ),
                    child: AnimatedSwitcher(
                      duration: AppMotion.normal,
                      switchInCurve: AppMotion.enter,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: switch (_step) {
                          0 => _buildPhotoStep(),
                          1 => _buildDetailStep(),
                          _ => _buildPricingStep(),
                        },
                      ),
                    ),
                  ),
                ),

                // ── Footer ───────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    AppSpacing.sm,
                    inset,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 15,
                              color: AppPalette.danger,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _error,
                                style: AppType.bodySmall.copyWith(
                                  color: AppPalette.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AppButton(
                        label: isLast ? 'Publish Listing' : 'Continue',
                        icon: isLast ? Icons.check : Icons.arrow_forward,
                        trailingIcon: true,
                        isLoading: _isSubmitting,
                        onPressed: _next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1 — photos ───────────────────────────────────────────────────
  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos'.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Natural light and a plain background sell faster.',
          style: AppType.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 3 / 4,
          ),
          itemCount: _kMaxPhotos,
          itemBuilder: (context, i) {
            if (i < _photos.length) {
              return _PhotoTile(
                file: _photos[i],
                isCover: i == 0,
                onRemove: () => setState(() {
                  _photos.removeAt(i);
                  _error = '';
                }),
              );
            }
            // Only the first empty slot is tappable, so the grid fills in
            // order and the cover is unambiguous.
            final isNextSlot = i == _photos.length;
            return GestureDetector(
              onTap: isNextSlot ? _addPhoto : null,
              child: Container(
                decoration: BoxDecoration(
                  color: AppPalette.surfaceMuted,
                  borderRadius: AppRadii.image,
                  border: Border.all(
                    color: isNextSlot ? AppPalette.lineStrong : AppPalette.line,
                  ),
                ),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  size: 20,
                  color: isNextSlot
                      ? AppPalette.accentDeep
                      : AppPalette.textTertiary,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '$_photoCount of $_kMaxPhotos added · the first becomes your cover',
          style: AppType.bodySmall,
        ),
      ],
    );
  }

  // ── Step 2 — details ──────────────────────────────────────────────────
  Widget _buildDetailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Title',
          hint: 'e.g. Wool blend blazer',
          controller: _titleController,
          onChanged: (_) {
            if (_error.isNotEmpty) setState(() => _error = '');
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Brand',
          hint: 'e.g. Zara',
          controller: _brandController,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Category'.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final category in _categories)
              AppChip(
                label: category,
                selected: _category == category,
                onTap: () => setState(() {
                  _category = category;
                  _error = '';
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Size'.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final size in _sizes)
              AppChip(
                label: size,
                selected: _size == size,
                onTap: () => setState(() {
                  _size = size;
                  _error = '';
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Condition'.toUpperCase(), style: AppType.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final condition in _conditions)
              AppChip(
                label: condition,
                selected: _condition == condition,
                onTap: () => setState(() {
                  _condition = condition;
                  _error = '';
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Description',
          hint: 'Fit, fabric, any flaws worth mentioning',
          controller: _descriptionController,
          maxLines: 4,
        ),
      ],
    );
  }

  // ── Step 3 — pricing ──────────────────────────────────────────────────
  Widget _buildPricingStep() {
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    // Platform economics, stated plainly rather than buried in terms.
    final commission = (price * 0.12).round();
    final payout = price - commission;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Your Price (₹)',
          hint: '899',
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          prefixIcon: Icons.currency_rupee,
          onChanged: (_) => setState(() => _error = ''),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Original Retail Price (₹)',
          hint: '2499 — optional, shows buyers the saving',
          controller: _originalPriceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() => _error = ''),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          color: AppPalette.surfaceWarm,
          bordered: false,
          child: Column(
            children: [
              _PayoutRow(label: 'Listing price', value: '₹$price'),
              const SizedBox(height: AppSpacing.xs),
              _PayoutRow(
                label: 'Platform fee (12%)',
                value: '−₹$commission',
                muted: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: AppDivider(),
              ),
              _PayoutRow(
                label: 'You receive',
                value: '₹${payout < 0 ? 0 : payout}',
                emphasised: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayoutRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  final bool emphasised;

  const _PayoutRow({
    required this.label,
    required this.value,
    this.muted = false,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasised
        ? AppType.titleMedium
        : AppType.bodyMedium.copyWith(
            color: muted ? AppPalette.textTertiary : AppPalette.textPrimary,
          );

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(
          value,
          style: emphasised ? AppType.priceLarge.copyWith(fontSize: 17) : style,
        ),
      ],
    );
  }
}

/// Confirmation after publishing. Uses the shared success state so it reads
/// like every other completion in the app.
class _ListingSubmittedScreen extends StatelessWidget {
  final String title;

  const _ListingSubmittedScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: AppStateView.success(
          title: 'Listing submitted',
          message:
              '"$title" is pending review. We\'ll notify you the moment '
              'it goes live — usually within an hour.',
          actionLabel: 'Back to Thrift',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

/// One captured photo, with a remove affordance and a cover marker on the
/// first slot.
class _PhotoTile extends StatelessWidget {
  final XFile file;
  final bool isCover;
  final VoidCallback onRemove;

  const _PhotoTile({
    required this.file,
    required this.isCover,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.image,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(file.path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: AppPalette.surfaceMuted,
              child: Icon(
                Icons.broken_image_outlined,
                size: 18,
                color: AppPalette.textTertiary,
              ),
            ),
          ),
          if (isCover)
            const Positioned(
              left: 4,
              bottom: 4,
              child: AppBadge('Cover', tone: AppBadgeTone.inverse),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppPalette.surfaceA92,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
