# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::CustomField, renamed from Spree::Metafield in
  # 6.0. Retained for one release; removed in 6.1.
  #
  # A plain constant alias rather than a DeprecatedConstantProxy: the proxy
  # would warn on first reference and name the calling site, but it fails
  # `is_a?`/`===` checks, so legacy code branching on the old constant would
  # silently take the wrong path. Correct behavior beats a better warning —
  # the rename is documented in the 5.6-to-6.0 upgrade guide instead.
  #
  # The underlying class, table (spree_custom_fields), prefix (cf) and
  # model_name are all Spree::CustomField; only the constant differs.
  Metafield = CustomField
end
