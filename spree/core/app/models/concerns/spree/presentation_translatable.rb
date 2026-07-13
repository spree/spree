module Spree
  # Shared by models whose single translatable field is the legacy
  # +presentation+ column exposed publicly as +label+ (OptionType, OptionValue).
  # Carries the Mobility setup, the translation-table normalizer, the
  # locale-aware +label+/+label=+ bridge, and the +label → presentation+
  # translation-matrix alias in one place so the two models don't restate it.
  module PresentationTranslatable
    extend ActiveSupport::Concern
    include Spree::TranslatableResource

    TRANSLATABLE_FIELDS = %i[presentation].freeze

    included do
      translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)

      self::Translation.class_eval do
        normalizes :presentation, with: ->(value) { value&.to_s&.squish&.presence }
      end
    end

    class_methods do
      # The translation matrix uses +label+ (the public API name) for read/write
      # symmetry; the +label+/+label=+ bridge below routes it to +presentation+.
      def translatable_field_aliases
        { label: :presentation }
      end
    end

    # alias_attribute bypasses Mobility's locale-aware reader/writer, so these
    # explicit delegations are required to keep +label+ translation-aware.
    def label(*args, **kwargs)
      presentation(*args, **kwargs)
    end

    def label=(value)
      self.presentation = value
    end
  end
end
