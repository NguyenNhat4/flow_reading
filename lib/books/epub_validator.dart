import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flow_reading/shared/app_failure.dart';
import 'package:xml/xml.dart';

final class ValidatedEpub {
  const ValidatedEpub({
    required this.archive,
    required this.packageDocumentPath,
    required this.chapterResourcePaths,
  });

  final Archive archive;
  final String packageDocumentPath;
  final List<String> chapterResourcePaths;
}

abstract final class EpubValidator {
  static const _mimetype = 'application/epub+zip';

  static ValidatedEpub validate(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      if (archive.isEmpty) {
        throw const InvalidEpubFailure(message: 'The EPUB archive is empty.');
      }

      _validateMimetype(archive);
      _rejectDrm(archive);

      final packagePath = _readPackagePath(archive);
      final packageDocument = _readXml(
        archive,
        packagePath,
        description: 'package document',
      );
      final chapterPaths = _readSpineResources(
        archive,
        packagePath,
        packageDocument,
      );

      return ValidatedEpub(
        archive: archive,
        packageDocumentPath: packagePath,
        chapterResourcePaths: List.unmodifiable(chapterPaths),
      );
    } on UnsupportedDrmFailure {
      rethrow;
    } on InvalidEpubFailure {
      rethrow;
    } catch (_) {
      throw const InvalidEpubFailure(
        message: 'The selected file is corrupted or is not a valid EPUB.',
      );
    }
  }

  static void _validateMimetype(Archive archive) {
    final mimetype = archive.find('mimetype');
    if (mimetype == null || !mimetype.isFile) {
      throw const InvalidEpubFailure(
        message: 'The EPUB mimetype file is missing.',
      );
    }
    if (archive.first.name != 'mimetype' ||
        mimetype.compression != CompressionType.none) {
      throw const InvalidEpubFailure(
        message: 'The EPUB mimetype entry is not stored correctly.',
      );
    }
    if (_readText(mimetype) != _mimetype) {
      throw const InvalidEpubFailure(message: 'The EPUB mimetype is invalid.');
    }
  }

  static void _rejectDrm(Archive archive) {
    if (archive.find('META-INF/rights.xml') != null) {
      throw const UnsupportedDrmFailure();
    }
    final encryption = archive.find('META-INF/encryption.xml');
    if (encryption == null) {
      return;
    }
    final document = _parseXml(_readText(encryption), 'encryption document');
    if (document.findAllElements('EncryptedData').isNotEmpty ||
        document.findAllElements('EncryptionMethod').isNotEmpty) {
      throw const UnsupportedDrmFailure();
    }
  }

  static String _readPackagePath(Archive archive) {
    final container = _readXml(
      archive,
      'META-INF/container.xml',
      description: 'container document',
    );
    final rootfiles = container.findAllElements('rootfile').toList();
    if (rootfiles.isEmpty) {
      throw const InvalidEpubFailure(
        message: 'The EPUB package document is not declared.',
      );
    }
    final path = rootfiles.first.getAttribute('full-path');
    if (path == null || path.isEmpty || !_isSafeArchivePath(path)) {
      throw const InvalidEpubFailure(
        message: 'The EPUB package document path is invalid.',
      );
    }
    if (archive.find(path) == null) {
      throw const InvalidEpubFailure(
        message: 'The EPUB package document is missing.',
      );
    }
    return path;
  }

  static List<String> _readSpineResources(
    Archive archive,
    String packagePath,
    XmlDocument packageDocument,
  ) {
    final manifests = packageDocument.findAllElements('manifest').toList();
    final spines = packageDocument.findAllElements('spine').toList();
    if (manifests.isEmpty || spines.isEmpty) {
      throw const InvalidEpubFailure(
        message: 'The EPUB package document has no manifest or spine.',
      );
    }

    final manifest = <String, String>{};
    for (final item in manifests.first.findElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && id.isNotEmpty && href != null && href.isNotEmpty) {
        manifest[id] = href;
      }
    }

    final itemRefs = spines.first.findElements('itemref').toList();
    if (itemRefs.isEmpty) {
      throw const InvalidEpubFailure(message: 'The EPUB spine is empty.');
    }

    final resources = <String>[];
    for (final itemRef in itemRefs) {
      final idref = itemRef.getAttribute('idref');
      final href = idref == null ? null : manifest[idref];
      if (href == null) {
        throw const InvalidEpubFailure(
          message: 'The EPUB spine references an unknown resource.',
        );
      }
      final resourcePath = _resolveArchivePath(packagePath, href);
      final resource = archive.find(resourcePath);
      if (resource == null || !resource.isFile) {
        throw InvalidEpubFailure(
          message: 'A chapter resource is missing: $resourcePath',
        );
      }
      resources.add(resourcePath);
    }
    return resources;
  }

  static XmlDocument _readXml(
    Archive archive,
    String path, {
    required String description,
  }) {
    final file = archive.find(path);
    if (file == null || !file.isFile) {
      throw InvalidEpubFailure(message: 'The EPUB $description is missing.');
    }
    return _parseXml(_readText(file), description);
  }

  static XmlDocument _parseXml(String value, String description) {
    try {
      return XmlDocument.parse(value);
    } on XmlParserException {
      throw InvalidEpubFailure(message: 'The EPUB $description is malformed.');
    }
  }

  static String _readText(ArchiveFile file) {
    return utf8.decode(file.readBytes()!, allowMalformed: false);
  }

  static String _resolveArchivePath(String packagePath, String href) {
    final hrefUri = Uri.parse(href);
    if (hrefUri.hasScheme || hrefUri.path.isEmpty) {
      throw const InvalidEpubFailure(
        message: 'The EPUB contains an invalid resource path.',
      );
    }
    final base = Uri(path: packagePath).resolve('.');
    final resolved = base.resolveUri(hrefUri).normalizePath().path;
    if (!_isSafeArchivePath(resolved)) {
      throw const InvalidEpubFailure(
        message: 'The EPUB contains an unsafe resource path.',
      );
    }
    return resolved;
  }

  static bool _isSafeArchivePath(String path) {
    return path.isNotEmpty &&
        !path.startsWith('/') &&
        !path.split('/').contains('..');
  }
}
