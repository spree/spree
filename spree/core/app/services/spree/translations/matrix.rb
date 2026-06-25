module Spree
  module Translations
    # Builds the admin translation matrix and field-discovery metadata for a
    # translatable record. Shared by the dedicated translations endpoint, the
    # +?expand=translations+ serializer attribute, and the discovery endpoint.
    class Matrix
      # HTML (rich-text) fields render as a rich-text editor; slug fields as a
      # slug input; everything else as a plain text input. Drives generic SPA
      # rendering without per-resource knowledge.
      HTML_FIELDS = %w[description body content].freeze
      SLUG_FIELDS = %w[slug permalink].freeze

      class << self
        # @return [Hash{String=>Hash}] locale => { field => value, "translated_field_count" => Integer }
        def for(record, locales: nil)
          fields = field_keys(record)
          locales ||= non_default_locales(record)

          locales.index_with do |locale|
            translated = field_values(record, locale, fields)
            translated.merge('translated_field_count' => translated.count { |_k, v| v.present? })
          end
        end

        # Full translation document for one record: resource_type, prefixed id,
        # discovery fields, and the matrix. Includes a nested +children+ array of
        # the same shape when the model declares translatable children (e.g. an
        # option type carries its option values) so an editor fetches a parent
        # and its children in one read. Writes stay flat (the batch endpoint).
        #
        # @param record [Spree.base_class]
        # @return [Hash]
        def document(record)
          doc = {
            'resource_type' => public_resource_type(record.class),
            'resource_id' => record.prefixed_id,
            'fields' => fields_for(record),
            'translations' => self.for(record)
          }

          children = translatable_children_for(record)
          doc['children'] = children.map { |child| document(child) } if children.any?
          doc
        end

        # @return [Array<Hash>] [{ "key" => "name", "type" => "string", "source" => "Espresso Machine" }, ...]
        def fields_for(record)
          Mobility.with_locale(default_locale(record)) do
            field_keys(record).map do |field|
              { 'key' => field, 'type' => field_type(field), 'source' => record.public_send(field) }
            end
          end
        end

        # @return [Array<Hash>] registry made public: [{ "resource_type" => "product", "fields" => [{key,type}] }]
        def registry
          Spree.translatable_resources.map do |klass|
            {
              'resource_type' => public_resource_type(klass),
              'fields' => klass.public_translatable_fields.map { |f| { 'key' => f.to_s, 'type' => field_type(f.to_s) } }
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
          return 'category' if klass <= Spree::Taxon

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

        def field_type(field)
          field = field.to_s
          return 'html' if HTML_FIELDS.include?(field)
          return 'slug' if SLUG_FIELDS.include?(field)

          'string'
        end

        private

        # Public field names, so the matrix read/write keys match the serializer
        # (e.g. OptionType exposes `label`, not the internal `presentation`).
        def field_keys(record)
          record.class.public_translatable_fields.map(&:to_s)
        end

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

        # Translatable child records to nest under a parent's document, when the
        # model declares them via +translatable_children+ (an association name).
        def translatable_children_for(record)
          assoc = record.class.try(:translatable_children)
          return [] if assoc.blank?

          Array(record.public_send(assoc))
        end

        def default_locale(record)
          record.translatable_store&.default_locale || I18n.default_locale.to_s
        end

        def non_default_locales(record)
          store = record.translatable_store
          return [] unless store

          (store.supported_locales_list - [store.default_locale]).sort
        end
      end
    end
  end
end
