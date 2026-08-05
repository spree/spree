# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::ReturnReason, renamed in 6.0 along with the
  # removal of the ReturnAuthorization chain. Retained for one release so
  # existing code and extensions keep working; removed in 6.1.
  #
  # A true constant alias — the class, table (spree_return_reasons), prefix
  # (rar) and model_name are all Spree::ReturnReason, so is_a?, polymorphic
  # type strings and class_name: references keep resolving correctly.
  ReturnAuthorizationReason = ReturnReason

  Spree::Deprecation.warn('Spree::ReturnAuthorizationReason is deprecated and will be removed in Spree 6.1. Use Spree::ReturnReason instead.')
end
