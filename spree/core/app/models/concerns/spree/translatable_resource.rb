module Spree
  module TranslatableResource
    extend ActiveSupport::Concern

    included do
      extend Mobility
      default_scope { i18n }
    end

    class_methods do
      def translatable_fields
        const_get(:TRANSLATABLE_FIELDS)
      end

      # Maps a public API field name to the internal Mobility field, for models
      # whose translatable column has a legacy name (e.g. OptionType exposes
      # +label+ but stores +presentation+). The public name is what the API
      # serializer and translation matrix use; the writer alias (+label=+)
      # already routes to the internal field through Mobility. Override per
      # model; default is identity.
      #
      # @return [Hash{Symbol=>Symbol}] public_name => internal_field
      def translatable_field_aliases
        {}
      end

      # The translatable fields by their PUBLIC API name (read/write symmetry),
      # substituting any aliased public name for the internal field.
      #
      # @return [Array<Symbol>]
      def public_translatable_fields
        inverse = translatable_field_aliases.invert
        translatable_fields.map { |field| inverse[field] || field }
      end

      # Translatable fields that hold rich text (HTML). Drives generic editor
      # rendering — the translation matrix tags these as +html+ so the SPA shows
      # a rich-text editor instead of a plain input. A +text+ column is
      # type-indistinguishable from a plain string, so the model must declare
      # which of its fields are rich text (via a +RICH_TEXT_TRANSLATABLE_FIELDS+
      # constant). Default is none.
      #
      # @return [Array<Symbol>] public field names
      def translatable_rich_text_fields
        const_defined?(:RICH_TEXT_TRANSLATABLE_FIELDS) ? const_get(:RICH_TEXT_TRANSLATABLE_FIELDS) : []
      end

      def translation_table_alias
        "#{self::Translation.table_name}_#{Mobility.normalize_locale(Mobility.locale)}"
      end

      def arel_table_alias
        Arel::Table.new(translation_table_alias)
      end
    end

    def get_field_with_locale(locale, field_name, fallback: false)
      # method will return nil if no translation is present due to fallback: false setting
      public_send(field_name, locale: locale, fallback: fallback)
    end

    # Upserts per-locale, per-field translations.
    #
    # Semantics (omit-to-leave-alone, never implicit-delete):
    # - a locale absent from +values+ is untouched
    # - a field absent within a present locale is untouched
    # - a field set to +""+ writes an empty string (read falls back to source
    #   via Mobility +column_fallback+); +nil+ deletes that cell
    #
    # Value normalization (HTML sanitization, slug parameterization) is owned by
    # the model's own writers — this only routes each value to its setter under
    # the right locale.
    #
    # @param values [Hash{String=>Hash{String=>String,nil}}] locale => { field => value }
    # @raise [ActiveRecord::RecordInvalid] on an unsupported locale or invalid save
    # @return [self]
    def upsert_translations(values)
      return self if values.blank?

      validate_translation_locales!(values.keys)
      # Accept (and write) the PUBLIC field names so read/write are symmetric
      # with the serializer. `label=` etc. delegate to the internal Mobility
      # field under the active locale.
      allowed = self.class.public_translatable_fields.map(&:to_s)

      transaction do
        values.each do |locale, fields|
          Mobility.with_locale(locale) do
            fields.to_h.slice(*allowed).each { |field, value| public_send("#{field}=", value) }
          end
        end
        save!
      end

      self
    end

    # The store whose supported locales gate which translations are allowed and
    # which locales the matrix exposes. The record's own store when it has one,
    # else the current store.
    def translatable_store
      return self if is_a?(Spree::Store)

      try(:store) || Spree::Current.store
    end

    private

    # @raise [ActiveRecord::RecordInvalid] if any locale isn't supported by the store
    def validate_translation_locales!(locales)
      supported = translatable_store&.supported_locales_list || []
      unsupported = locales.map(&:to_s) - supported.map(&:to_s)
      return if unsupported.empty?

      errors.add(:base, :unsupported_locale, message: "Unsupported locale(s): #{unsupported.join(', ')}")
      raise ActiveRecord::RecordInvalid, self
    end
  end
end
