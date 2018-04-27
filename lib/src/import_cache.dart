// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_import_cache.dart.
// See tool/synchronize.dart for details.
//
// Checksum: 9991d971f6d19e004ea2fa5d561b47163ae79f93

import 'package:tuple/tuple.dart';

import 'ast/sass.dart';
import 'importer.dart';
import 'logger.dart';

import 'util/path.dart';

/// An in-memory cache of parsed stylesheets that have been imported by Sass.
class ImportCache {
  /// A cache that contains no importers.
  static const none = const ImportCache._none();

  /// The importers to use when loading new Sass files.
  final List<Importer> _importers;

  /// The logger to use to emit warnings when parsing stylesheets.
  final Logger _logger;

  /// The canonicalized URLs for each non-canonical URL.
  ///
  /// This cache isn't used for relative imports, because they're
  /// context-dependent.
  final Map<Uri, Tuple2<Importer, Uri>> _canonicalizeCache;

  /// The parsed stylesheets for each canonicalized import URL.
  final Map<Uri, Stylesheet> _importCache;

  /// Creates an import cache that resolves imports using [importers].
  ///
  /// Earlier importers will be preferred.
  ImportCache(Iterable<Importer> importers, {Logger logger})
      : _importers = new List.unmodifiable(importers),
        _logger = logger ?? const Logger.stderr(),
        _canonicalizeCache = {},
        _importCache = {};

  /// Creates a cache that contains no importers.
  const ImportCache._none()
      : _importers = const [],
        _logger = const Logger.stderr(),
        _canonicalizeCache = const {},
        _importCache = const {};

  /// Returns the canonical form of [url] according to one of this cache's
  /// importers.
  ///
  /// If [baseImporter] and [baseUrl] are both non-`null` *and* [url] is
  /// relative, this first tries to use [baseImporter] to canonicalize [url]
  /// relative to [baseUrl].
  ///
  /// If any importers understand [url], returns that importer as well as the
  /// canonicalized URL. Otherwise, returns `null`.
  Tuple2<Importer, Uri> canonicalize(Uri url,
      [Importer baseImporter, Uri baseUrl]) {
    if (baseImporter != null && baseUrl != null && url.scheme.isEmpty) {
      var canonicalUrl = baseImporter.canonicalize(baseUrl.resolveUri(url));
      if (canonicalUrl != null) return new Tuple2(baseImporter, canonicalUrl);
    }

    return _canonicalizeCache.putIfAbsent(url, () {
      for (var importer in _importers) {
        var canonicalUrl = importer.canonicalize(url);
        if (canonicalUrl != null) return new Tuple2(importer, canonicalUrl);
      }

      return null;
    });
  }

  /// Tries to import [url] using one of this cache's importers.
  ///
  /// If [baseImporter] and [baseUrl] are both non-`null` *and* [url] is
  /// relative, this first tries to use [baseImporter] to import [url] relative
  /// to [baseUrl].
  ///
  /// If any importers can import [url], returns that importer as well as the
  /// parsed stylesheet. Otherwise, returns `null`.
  ///
  /// Caches the result of the import and uses cached results if possible.
  Tuple2<Importer, Stylesheet> import(Uri url,
      [Importer baseImporter, Uri baseUrl]) {
    var tuple = canonicalize(url, baseImporter, baseUrl);
    var stylesheet = importCanonical(tuple.item1, tuple.item2);
    return new Tuple2(tuple.item1, stylesheet);
  }

  /// Tries to load the canonicalized [canonicalUrl] using [importer].
  ///
  /// If [importer] can import [canonicalUrl], returns the imported [Stylesheet].
  /// Otherwise returns `null`.
  ///
  /// If passed, the [originalUrl] represents the URL that was canonicalized
  /// into [canonicalUrl]. It's used as the URL for the parsed stylesheet, which
  /// is in turn used in error reporting.
  ///
  /// Caches the result of the import and uses cached results if possible.
  Stylesheet importCanonical(Importer importer, Uri canonicalUrl,
      [Uri originalUrl]) {
    return _importCache.putIfAbsent(canonicalUrl, () {
      var result = importer.load(canonicalUrl);
      if (result == null) return null;

      // Use the canonicalized basename so that we display e.g.
      // package:example/_example.scss rather than package:example/example in
      // stack traces.
      var displayUrl = originalUrl == null
          ? canonicalUrl
          : originalUrl.resolve(pUrl.basename(canonicalUrl.path));
      return result.isIndented
          ? new Stylesheet.parseSass(result.contents,
              url: displayUrl, logger: _logger)
          : new Stylesheet.parseScss(result.contents,
              url: displayUrl, logger: _logger);
    });
  }
}
