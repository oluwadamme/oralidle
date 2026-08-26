/// Which account the local Hive rows belong to.
///
/// Empty while the user is anonymous, the uid once they have linked an email.
/// Every local read and write is confined to the current scope, so signing in
/// as someone else on a shared device cannot surface — or re-upload — the
/// previous account's recordings.
///
/// Anonymous data deliberately lives under the empty scope rather than under
/// the anonymous uid: an anonymous token can be lost (cleared site data, an
/// expiring private window) and the next launch signs in with a *new* uid. Keyed
/// by uid, that history would be stranded under a namespace nothing ever reads
/// again. Keyed by "", it survives and is claimed by whoever links next.
///
/// A plain mutable holder rather than a derived provider on purpose: the scope
/// comes from auth, auth needs sync, and sync needs storage — deriving it would
/// close that loop.
class StorageScope {
  /// '' for anonymous, otherwise the linked account's uid.
  String value = anonymous;

  static const anonymous = '';
}
