# frozen_string_literal: true

module Spree
  # Deprecation bridge for the 6.0 custom-fields rename. Serves the two roles
  # the old `Spree::Metafields` name had, and is removed in 6.1:
  #
  # 1. The concern — `include Spree::Metafields` still works and gives a model
  #    the full custom-fields surface via {Spree::HasCustomFields}.
  # 2. The STI namespace — `Spree::Metafields::ShortText` and friends are
  #    constant aliases for `Spree::CustomFields::*`. The `type` column stores
  #    the new class names, so these resolve to the very same classes and
  #    existing rows keep loading.
  module Metafields
    extend ActiveSupport::Concern

    ShortText = CustomFields::ShortText
    LongText = CustomFields::LongText
    RichText = CustomFields::RichText
    Number = CustomFields::Number
    Boolean = CustomFields::Boolean
    Json = CustomFields::Json

    included do
      Spree::Deprecation.warn(
        "include Spree::Metafields is deprecated and will be removed in Spree 6.1. " \
        "Use include Spree::HasCustomFields instead (#{name})."
      )

      include Spree::HasCustomFields
    end
  end
end
