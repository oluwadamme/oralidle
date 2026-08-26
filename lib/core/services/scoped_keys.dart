/// Hive key layout for scoped rows.
///
/// A linked account's rows are keyed `<uid>:<id>`; anonymous rows keep the bare
/// `<id>`. Leaving the anonymous form unprefixed means every row written before
/// scoping existed is already in the right namespace — there is no data
/// migration to run, and no window where a botched one loses history.
///
/// Safe because both uids and row ids are UUIDs, which never contain a colon.
abstract final class ScopedKeys {
  static String of(String scope, String id) => scope.isEmpty ? id : '$scope:$id';

  static bool matches(Object? key, String scope) {
    if (key is! String) return false;
    return scope.isEmpty ? !key.contains(':') : key.startsWith('$scope:');
  }

  static String idFrom(String key) {
    final separator = key.indexOf(':');
    return separator == -1 ? key : key.substring(separator + 1);
  }
}
