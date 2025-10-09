/// Configuration for response caching
class CacheConfig {
  final Duration maxAge;
  final bool persist;
  final int maxSize;
  final bool forceRefresh;
  
  const CacheConfig({
    this.maxAge = const Duration(hours: 1),
    this.persist = false,
    this.maxSize = 100,
    this.forceRefresh = false,
  });
  
  CacheConfig copyWith({
    Duration? maxAge,
    bool? persist,
    int? maxSize,
    bool? forceRefresh,
  }) {
    return CacheConfig(
      maxAge: maxAge ?? this.maxAge,
      persist: persist ?? this.persist,
      maxSize: maxSize ?? this.maxSize,
      forceRefresh: forceRefresh ?? this.forceRefresh,
    );
  }
}
