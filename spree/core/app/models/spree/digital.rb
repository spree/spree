# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::DigitalAsset, renamed from Spree::Digital in
  # 6.0. Retained for one release; removed in 6.1.
  #
  # A plain constant alias rather than a DeprecatedConstantProxy: the proxy
  # would name the calling site, but it fails `is_a?`/`===` checks, so legacy
  # code branching on the old constant would silently take the wrong path.
  #
  # The underlying class, table (spree_digital_assets), prefix (dig) and
  # model_name are all Spree::DigitalAsset; only the constant differs.
  Digital = DigitalAsset
end
