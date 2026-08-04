/// Temporary product feature flags.
///
/// Flip these to re-enable UI without restoring deleted code.
class FeatureFlags {
  FeatureFlags._();

  /// When `false`, Settings / Send / notices that mention AI stay hidden.
  /// Underlying services (`AiImageGenerateService`, etc.) remain in the tree.
  static const bool enableAIFeatures = false;
}
