# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::Media, renamed from Spree::Asset in 6.0.
  # Retained for one release so existing code and extensions that reference
  # Spree::Asset keep working; the canonical class is Spree::Media. Removed in
  # 6.1, together with Spree::Image (which this replaces).
  #
  # This is a true constant alias — the underlying class, table (spree_media)
  # and prefix (media) are all Spree::Media. Only the constant differs, so
  # is_a?, polymorphic *_type strings, and class_name: references keep
  # resolving to Spree::Media.
  Asset = Media

  Spree::Deprecation.warn('Spree::Asset is deprecated and will be removed in Spree 6.1. Use Spree::Media instead.')
end
