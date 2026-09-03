module Spree
  # Shared by models whose single translatable field is +label+ (OptionType,
  # OptionValue). Carries the Mobility setup and the translation-table
  # normalizer in one place so the two models don't restate it.
  module LabelTranslatable
    extend ActiveSupport::Concern
    include Spree::TranslatableResource

    TRANSLATABLE_FIELDS = %i[label].freeze

    included do
      translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)

      self::Translation.class_eval do
        normalizes :label, with: ->(value) { value&.to_s&.squish&.presence }
      end
    end

    # @deprecated The column is +label+ since 6.0; removed in 6.1.
    #
    # Unlike the attribute aliases the other 6.0 renames use, this is a plain
    # method — Mobility owns +label+, so it cannot be an alias_attribute. It
    # therefore reads and writes only on an instance: +where(presentation:)+
    # and +find_by(presentation:)+ name a column that no longer exists and
    # raise. Query by +label+.
    def presentation(*args, **kwargs)
      Spree::Deprecation.warn("#{self.class.name}#presentation is deprecated and will be removed in Spree 6.1. Use #label instead.")
      label(*args, **kwargs)
    end

    # @deprecated See {#presentation}; removed in 6.1.
    def presentation=(value)
      Spree::Deprecation.warn("#{self.class.name}#presentation= is deprecated and will be removed in Spree 6.1. Use #label= instead.")
      self.label = value
    end
  end
end
