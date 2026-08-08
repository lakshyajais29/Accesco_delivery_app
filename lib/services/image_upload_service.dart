import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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

/// Uploads listing photographs to Firebase Storage and returns their download
/// URLs.
///
/// Design notes:
///
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

  /// Injectable for tests.
  @visibleForTesting
  FirebaseStorage storage = FirebaseStorage.instance;

  /// Root folder for listing photography.
  static const String _listingFolder = 'thrift_listings';

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

    // Byte-weighted progress needs the totals up front.
    final sizes = <int>[];
    var totalBytes = 0;
    for (final file in files) {
      final length = await File(file.path).length();
      sizes.add(length);
      totalBytes += length;
    }
    if (totalBytes == 0) {
      throw const ImageUploadException('Those photos appear to be empty.');
    }

    final urls = <String>[];
    final uploadedRefs = <Reference>[];
    var bytesDone = 0;

    void report(int completed, int inFlightBytes) {
      onProgress?.call(
        UploadProgress(
          completed: completed,
          total: files.length,
          fraction: ((bytesDone + inFlightBytes) / totalBytes).clamp(0.0, 1.0),
        ),
      );
    }

    report(0, 0);

    try {
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final extension = _extensionOf(file.path);
        final ref = storage
            .ref()
            .child(_listingFolder)
            .child(sellerId)
            .child(batchId)
            .child('$i$extension');

        final task = ref.putFile(
          File(file.path),
          SettableMetadata(
            contentType: _contentTypeFor(extension),
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
          await task;
        } finally {
          await subscription.cancel();
        }

        urls.add(await ref.getDownloadURL());
        uploadedRefs.add(ref);
        bytesDone += sizes[i];
        report(i + 1, 0);
      }

      return urls;
    } on FirebaseException catch (error) {
      await _rollback(uploadedRefs);
      throw ImageUploadException(_messageFor(error));
    } catch (error) {
      await _rollback(uploadedRefs);
      debugPrint('ImageUploadService failed: $error');
      throw const ImageUploadException(
        'Could not upload your photos. Check your connection and try again.',
      );
    }
  }

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
