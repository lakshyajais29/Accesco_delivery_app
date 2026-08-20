import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Progress of a multi-file upload.
///
/// [fraction] is byte-weighted rather than file-weighted: a 4 MB photo and a
/// 200 KB photo are not equal thirds of the work, and a file-counting bar
/// visibly stalls on the large one.
class UploadProgress {
  /// Files fully uploaded so far.
  final int completed;

  /// Total files in this batch.
  final int total;

  /// Overall completion, 0.0–1.0, weighted by bytes.
  final double fraction;

  const UploadProgress({
    required this.completed,
    required this.total,
    required this.fraction,
  });

  /// One-based index of the file currently uploading, clamped to [total] so
  /// the label never reads "4 of 3" on the final byte.
  int get currentIndex => (completed + 1) > total ? total : completed + 1;

  int get percent => (fraction * 100).round();
}

/// Raised when an upload cannot be completed. The message is already phrased
/// for display.
class ImageUploadException implements Exception {
  final String message;

  const ImageUploadException(this.message);

  @override
  String toString() => 'ImageUploadException: $message';
}

/// One photo, decoded down to upload size and re-encoded.
class _PreparedImage {
  final Uint8List bytes;
  final String extension;
  final String contentType;

  const _PreparedImage({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  int get length => bytes.length;
}

/// Runs in a background isolate — JPEG encoding is pure CPU and would jank the
/// swipe/scroll animations if it ran on the UI thread.
///
/// Top-level by necessity: [compute] can only hand a closure-free function to
/// the isolate.
Uint8List _encodeJpeg((Uint8List, int, int, int) args) {
  final (rgba, width, height, quality) = args;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: quality);
}

/// Uploads listing photographs to Firebase Storage and returns their download
/// URLs.
///
/// Design notes:
///
///  * Photos are **downscaled and re-encoded before upload** — see
///    [maxDimension]/[jpegQuality]. A modern phone camera produces 4–12 MB
///    originals; sending those raw costs the seller their data allowance, and
///    the Virtual Try-On API rejects or times out on them.
///  * Uploads run **sequentially**. Six concurrent putFile tasks on a phone
///    connection contend for the same uplink and make per-file progress
///    meaningless; one at a time gives an honest bar and a clean failure point.
///  * A failure **rolls back** everything already uploaded in that batch.
///    Without it a retry would orphan the earlier objects, and nothing would
///    ever delete them — Storage bills for orphans indefinitely.
///  * Paths are namespaced by seller uid so Storage rules can restrict writes
///    to `request.auth.uid`, which is the only thing stopping one user from
///    overwriting another's photos.
class ImageUploadService {
  ImageUploadService._();

  static final ImageUploadService instance = ImageUploadService._();

  FirebaseStorage? _storage;

  /// Lazy, not a field initializer: `FirebaseStorage.instance` throws
  /// synchronously when Firebase has not initialised, and from a field
  /// initializer that throw escapes the constructor — before any method's
  /// try/catch can convert it into an [ImageUploadException].
  FirebaseStorage get storage => _storage ??= FirebaseStorage.instance;

  /// Injectable for tests.
  @visibleForTesting
  set storage(FirebaseStorage value) => _storage = value;

  /// Root folder for listing photography.
  static const String _listingFolder = 'thrift_listings';

  /// Longest edge, in pixels, of an uploaded photo.
  ///
  /// 1024 matches what the product cards and the try-on pipeline consume; the
  /// extra pixels in a 4032 px original are discarded on the server anyway.
  static const int maxDimension = 1024;

  /// JPEG quality for re-encoded photos. 85 is the standard point where
  /// artefacts stay invisible on a phone screen.
  static const int jpegQuality = 85;

  /// Ceiling on a single file's upload. Generous — a compressed photo is a few
  /// hundred KB, so anything beyond this is a stalled connection, not a slow
  /// one. Without it a dead uplink leaves the progress sheet spinning forever.
  static const Duration perFileTimeout = Duration(seconds: 90);

  /// Ceiling on resolving a download URL once the bytes are up.
  static const Duration urlTimeout = Duration(seconds: 30);

  /// Uploads [files] and returns their download URLs, in the same order.
  ///
  /// [sellerId] must be the authenticated user's uid — it becomes part of the
  /// storage path that security rules match on.
  ///
  /// Returns an empty list for empty input rather than throwing, so a caller
  /// doesn't need to special-case "no photos".
  Future<List<String>> uploadListingImages(
    List<XFile> files, {
    required String sellerId,
    ValueChanged<UploadProgress>? onProgress,
  }) async {
    if (files.isEmpty) return const [];

    // Group every photo in one batch folder so a listing's images stay
    // together and can be removed with a single prefix delete.
    final batchId = DateTime.now().millisecondsSinceEpoch.toString();

    final urls = <String>[];
    final uploadedRefs = <Reference>[];

    try {
      // ── Prepare ────────────────────────────────────────────────────────
      // Reading and compressing happens inside the guard: a deleted temp file,
      // a permissions failure, or an unreadable image all surface here as a
      // display-ready exception rather than an uncaught FileSystemException.
      final prepared = <_PreparedImage>[];
      var totalBytes = 0;
      for (final file in files) {
        final image = await _prepare(file);
        prepared.add(image);
        totalBytes += image.length;
      }
      if (totalBytes == 0) {
        throw const ImageUploadException('Those photos appear to be empty.');
      }

      var bytesDone = 0;
      void report(int completed, int inFlightBytes) {
        onProgress?.call(
          UploadProgress(
            completed: completed,
            total: files.length,
            fraction:
                ((bytesDone + inFlightBytes) / totalBytes).clamp(0.0, 1.0),
          ),
        );
      }

      report(0, 0);

      // ── Upload ─────────────────────────────────────────────────────────
      for (var i = 0; i < prepared.length; i++) {
        final image = prepared[i];
        final ref = storage
            .ref()
            .child(_listingFolder)
            .child(sellerId)
            .child(batchId)
            .child('$i${image.extension}');

        final task = ref.putData(
          image.bytes,
          SettableMetadata(
            contentType: image.contentType,
            // Listing photos are immutable once published; a long cache is
            // safe and keeps the marketplace grid cheap to re-render.
            cacheControl: 'public, max-age=604800',
            customMetadata: {'sellerId': sellerId, 'batchId': batchId},
          ),
        );

        final subscription = task.snapshotEvents.listen(
          (snapshot) => report(i, snapshot.bytesTransferred),
          // Errors surface by awaiting the task; swallowing them here just
          // stops an unhandled async error from the stream.
          onError: (_) {},
        );

        try {
          await task.timeout(
            perFileTimeout,
            onTimeout: () {
              // Cancel before throwing, or the task keeps consuming the
              // uplink behind a screen the user has already given up on.
              unawaited(task.cancel().catchError((_) => false));
              throw TimeoutException('Upload stalled', perFileTimeout);
            },
          );
        } finally {
          await subscription.cancel();
        }

        urls.add(await ref.getDownloadURL().timeout(urlTimeout));
        uploadedRefs.add(ref);
        bytesDone += image.length;
        report(i + 1, 0);
      }

      return urls;
    } on ImageUploadException {
      await _rollback(uploadedRefs);
      rethrow;
    } on TimeoutException {
      await _rollback(uploadedRefs);
      throw const ImageUploadException(
        'The upload timed out. Check your connection and try again.',
      );
    } on FirebaseException catch (error) {
      await _rollback(uploadedRefs);
      throw ImageUploadException(_messageFor(error));
    } on FileSystemException catch (error) {
      await _rollback(uploadedRefs);
      debugPrint('ImageUploadService could not read a photo: $error');
      throw const ImageUploadException(
        'One of those photos could not be read. Please pick it again.',
      );
    } catch (error) {
      await _rollback(uploadedRefs);
      debugPrint('ImageUploadService failed: $error');
      throw const ImageUploadException(
        'Could not upload your photos. Check your connection and try again.',
      );
    }
  }

  // ── Compression ──────────────────────────────────────────────────────────

  /// Reads [file] and returns it downscaled to [maxDimension] and re-encoded
  /// as JPEG.
  ///
  /// Falls back to the original bytes when the image cannot be decoded — some
  /// HEIC variants have no platform decoder, and shipping the original is far
  /// better than failing the listing outright.
  Future<_PreparedImage> _prepare(XFile file) async {
    final original = await File(file.path).readAsBytes();

    try {
      final compressed = await _downscaleToJpeg(original);
      if (compressed != null && compressed.length < original.length) {
        debugPrint(
          'ImageUploadService: ${_kb(original.length)} → '
          '${_kb(compressed.length)} (${file.name})',
        );
        return _PreparedImage(
          bytes: compressed,
          extension: '.jpg',
          contentType: 'image/jpeg',
        );
      }
    } catch (error) {
      // Never fatal — fall through to the original below.
      debugPrint('ImageUploadService: compression skipped for '
          '${file.name} — $error');
    }

    final extension = _extensionOf(file.path);
    return _PreparedImage(
      bytes: original,
      extension: extension,
      contentType: _contentTypeFor(extension),
    );
  }

  /// Decodes [bytes] at reduced resolution and re-encodes as JPEG.
  ///
  /// The decode runs through `dart:ui`, which uses the *platform* codec — so
  /// HEIC, WebP and PNG all work wherever the OS supports them, and the
  /// downscale happens during decode. A 12 MP original is therefore never
  /// fully materialised in memory. Only the JPEG encode is pure Dart, and that
  /// runs off the UI thread.
  ///
  /// Returns null when the image is already within [maxDimension] — re-encoding
  /// a small photo only loses quality.
  Future<Uint8List?> _downscaleToJpeg(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
    } catch (_) {
      buffer.dispose();
      rethrow;
    }

    final width = descriptor.width;
    final height = descriptor.height;
    final longest = width > height ? width : height;

    if (longest <= maxDimension) {
      descriptor.dispose();
      return null;
    }

    final scale = maxDimension / longest;
    final targetWidth = (width * scale).round();
    final targetHeight = (height * scale).round();

    final codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );

    ui.Image? image;
    try {
      final frame = await codec.getNextFrame();
      image = frame.image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) return null;

      // Copy out of the view before crossing the isolate boundary — passing a
      // ByteData's backing buffer directly would send the wrong window when
      // the view carries a non-zero offset.
      final pixels = Uint8List.fromList(
        rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
      );

      return await compute(
        _encodeJpeg,
        (pixels, image.width, image.height, jpegQuality),
      );
    } finally {
      image?.dispose();
      codec.dispose();
      descriptor.dispose();
    }
  }

  String _kb(int bytes) => '${(bytes / 1024).round()} KB';

  /// Best-effort cleanup of a partially uploaded batch.
  ///
  /// Deliberately swallows its own failures: the caller is already handling a
  /// primary error, and a failed cleanup must not mask it.
  Future<void> _rollback(List<Reference> refs) async {
    for (final ref in refs) {
      try {
        await ref.delete();
      } catch (error) {
        debugPrint('Rollback failed for ${ref.fullPath}: $error');
      }
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    final extension = path.substring(dot).toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};
    return allowed.contains(extension) ? extension : '.jpg';
  }

  String _contentTypeFor(String extension) => switch (extension) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.heic' => 'image/heic',
        _ => 'image/jpeg',
      };

  /// Turns a Storage error code into something a seller can act on.
  String _messageFor(FirebaseException error) => switch (error.code) {
        'unauthorized' || 'permission-denied' =>
          'You don\'t have permission to upload. Please sign in again.',
        'canceled' => 'Upload cancelled.',
        'quota-exceeded' =>
          'Storage is temporarily full. Please try again shortly.',
        'retry-limit-exceeded' =>
          'The upload kept failing. Check your connection and retry.',
        'object-not-found' => 'That file could no longer be found.',
        _ => 'Could not upload your photos. Please try again.',
      };
}
