// Success envelopes from spec §2.2.
//
// Non-paginated endpoints wrap their payload in `ApiResponse`:
//   { "data": {...}, "timestamp": "..." }
//
// Cursor list endpoints use `PagedResponse`:
//   { "data": [...], "pagination": { nextCursor, hasMore, limit } }

/// Pulls the `data` field out of an `ApiResponse`-shaped body, tolerating a
/// bare payload (some endpoints return the object directly).
T unwrapData<T>(Object? body, T Function(Object? data) parse) {
  if (body is Map<String, dynamic> && body.containsKey('data')) {
    return parse(body['data']);
  }
  return parse(body);
}

/// A page of results plus the opaque cursor to fetch the next page (spec §2.2).
class PagedResponse<T> {
  const PagedResponse({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.limit,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final int limit;

  bool get isEmpty => items.isEmpty;

  factory PagedResponse.fromBody(
    Object? body,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final rawItems = map['data'];
    final items = <T>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map<String, dynamic>) items.add(itemParser(e));
      }
    }
    final pagination = map['pagination'];
    String? nextCursor;
    bool hasMore = false;
    int limit = 20;
    if (pagination is Map<String, dynamic>) {
      nextCursor = pagination['nextCursor'] as String?;
      hasMore = pagination['hasMore'] == true;
      final l = pagination['limit'];
      if (l is int) limit = l;
    }
    return PagedResponse(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      limit: limit,
    );
  }

  PagedResponse<T> append(PagedResponse<T> next) => PagedResponse(
        items: [...items, ...next.items],
        nextCursor: next.nextCursor,
        hasMore: next.hasMore,
        limit: next.limit,
      );
}

/// Parses an `ApiResponse<List<...>>` (the non-paginated list endpoints:
/// KYC documents, notifications).
List<T> parseDataList<T>(
  Object? body,
  T Function(Map<String, dynamic>) itemParser,
) {
  final data = (body is Map<String, dynamic>) ? body['data'] : body;
  if (data is List) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(itemParser)
        .toList(growable: false);
  }
  return const [];
}
