# frozen_string_literal: true

module Spree
  # Builds the admin translation matrix, field-discovery metadata, and the
  # public translatable-resource registry for records in
  # +Spree.translatable_resources+. Stateless helper shared by the dedicated
  # translations endpoint, the +?expand=translations+ serializer attribute, the
  # batch write controller, and the discovery endpoint.
  module Translations
    module_function

    # @return [Hash{String=>Hash}] locale => { field => value, "translated_field_count" => Integer }
    def matrix_for(record, locales: nil)
      fields = field_keys(record)
      locales ||= non_default_locales(record)

      locales.index_with do |locale|
        translated = field_values(record, locale, fields)
        translated.merge('translated_field_count' => translated.count { |_k, v| v.present? })
      end
    end

    # @return [Array<Hash>] [{ "key" => "name", "type" => "string", "source" => "Espresso Machine" }, ...]
    def fields_for(record)
      Mobility.with_locale(default_locale(record)) do
        field_keys(record).map do |field|
          { 'key' => field, 'type' => field_type(record.class, field), 'source' => record.public_send(field) }
        end
      end
    end

    # @return [Array<Hash>] registry made public: [{ "resource_type" => "product", "fields" => [{key,type}] }]
    def registry
      Spree.translatable_resources.map do |klass|
        {
          'resource_type' => public_resource_type(klass),
          'fields' => klass.public_translatable_fields.map { |f| { 'key' => f.to_s, 'type' => field_type(klass, f) } }
        }
      end
    end

    # @return [String] underscored, demodulized model name (e.g. "option_type")
    def resource_type(klass)
      klass.name.demodulize.underscore
    end

    # The PUBLIC resource-type token used in read (document/registry) and
    # write (batch) payloads. Taxon is exposed as "category" (routes use the
    # 5.5 rename) while the model element stays "taxon"; this keeps the read
    # and write contracts consistent.
    #
    # @return [String]
    def public_resource_type(klass)
      return 'category' if klass <= Spree::Category

      resource_type(klass)
    end

    # Inverse of +public_resource_type+: maps a public token to its
    # registered translatable class, or nil if not translatable.
    #
    # @param token [String, Symbol] e.g. "product", "option_value", "category"
    # @return [Class, nil]
    def resource_class(token)
      # Recomputed per call (not memoized) so a dev-mode class reload of a
      # registry member doesn't leave a stale class reference behind.
      map = Spree.translatable_resources.index_by { |klass| public_resource_type(klass) }
      map[token.to_s]
    end

    # The editor type for a translatable field: +html+ when the model declares
    # it as rich text (drives a rich-text editor in the SPA), else +string+.
    # @param klass [Class] a translatable model
    # @param field [String, Symbol] public field name
    # @return [String]
    def field_type(klass, field)
      klass.translatable_rich_text_fields.map(&:to_sym).include?(field.to_sym) ? 'html' : 'string'
    end

    # Public field names, so the matrix read/write keys match the serializer
    # (e.g. OptionType exposes `label`, not the internal `presentation`).
    def field_keys(record)
      record.class.public_translatable_fields.map(&:to_s)
    end
    private_class_method :field_keys

    def field_values(record, locale, fields)
      Mobility.with_locale(locale) do
        fields.index_with do |field|
          # fallback: false so an absent translation reads as nil, not the source value
          record.public_send(field, fallback: false)
        rescue ArgumentError
          # fields without a Mobility reader signature still respond to the bare getter
          record.public_send(field)
        end
      end
    end
    private_class_method :field_values

    def default_locale(record)
      record.translatable_store&.default_locale || I18n.default_locale.to_s
    end
    private_class_method :default_locale

    def non_default_locales(record)
      store = record.translatable_store
      return [] unless store

      (store.supported_locales_list - [store.default_locale]).sort
    end
    private_class_method :non_default_locales
  end
end
