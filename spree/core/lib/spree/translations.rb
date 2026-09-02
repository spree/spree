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
      locales ||= non_default_locales(record.translatable_store)

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

    # Per-locale coverage for a whole resource type: how many of each record's
    # translatable fields are filled in, per locale, in ONE query per resource
    # type rather than one per record (the legacy admin page's N+1).
    #
    # Counting every field rather than just the first is deliberate: a product
    # whose name is translated but whose description is not is not "translated"
    # (see the plan's Key Decision 15).
    #
    # @param records [ActiveRecord::Relation] the page of records to report on
    # @param klass [Class] the translatable model
    # @param locales [Array<String>] non-default locales to report
    # @return [Hash{Integer=>Hash{String=>Integer}}] record id => locale => filled field count
    def translated_counts(records, klass, locales)
      return {} if locales.empty?

      record_ids = records.map(&:id)
      return {} if record_ids.empty?

      columns = internal_field_columns(klass)
      rows = translation_scope(klass).
             where(foreign_key(klass) => record_ids, locale: locales).
             pluck(foreign_key(klass), :locale, *columns)

      rows.each_with_object({}) do |row, counts|
        record_id, locale, *values = row
        filled = values.count { |value| value.to_s.present? }
        next if filled.zero?

        (counts[record_id] ||= {})[locale.to_s] = filled
      end
    end

    # Store-wide totals per locale: how many records have every translatable
    # field filled in, out of how many records there are.
    #
    # @param scope [ActiveRecord::Relation] every record of this type in the store
    # @param klass [Class]
    # @param locales [Array<String>]
    # @return [Array<Hash>] one entry per locale
    def coverage_for(scope, klass, locales)
      return [] if locales.empty?

      total = scope.count
      complete = complete_counts_by_locale(scope, klass, locales)

      locales.map do |locale|
        translated = complete[locale].to_i

        {
          'locale' => locale,
          'translated' => translated,
          'total' => total,
          'coverage' => total.positive? ? (translated.to_f / total).round(4) : 0.0
        }
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

    # The permission resource a translatable model is read under — an option
    # type's translations ride `products`, a policy's ride `settings`. Shared
    # by the per-resource and coverage endpoints so the rule has one home.
    #
    # @param klass [Class]
    # @return [Symbol]
    def permission_resource_name(klass)
      Spree.permissions.resource_for_subject(klass)&.name ||
        public_resource_type(klass).pluralize.to_sym
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

    # The locales a store translates INTO — everything it supports except the
    # one its source content is written in.
    #
    # @param store [Spree::Store]
    # @return [Array<String>] sorted locale codes
    def non_default_locales(store)
      return [] unless store

      (store.supported_locales_list - [store.default_locale]).sort
    end

    # How many records are fully translated, per locale, counted in the database
    # rather than by loading every record's ids into Ruby — the store-wide
    # totals span the whole catalog, not the page being displayed.
    #
    # @return [Hash{String=>Integer}] locale => number of fully translated records
    def complete_counts_by_locale(scope, klass, locales)
      columns = internal_field_columns(klass)
      table = klass::Translation.arel_table

      # A record counts for a locale only when every translatable column on its
      # translation row is non-blank. Columns come from the model's own
      # TRANSLATABLE_FIELDS, but they are quoted as identifiers regardless
      # rather than interpolated raw.
      # TRIM so this agrees with the per-record counter, which uses Ruby's
      # `present?` — otherwise a whitespace-only translation counts as complete
      # in the totals while every grid cell below shows it as missing.
      all_present = columns.map { |column|
        quoted = "#{table.name}.#{klass.connection.quote_column_name(column)}"
        "#{quoted} IS NOT NULL AND TRIM(#{quoted}) != ''"
      }.join(' AND ')

      translation_scope(klass).
        where(foreign_key(klass) => scope.select(:id), locale: locales).
        where(all_present).
        group(:locale).
        count.
        transform_keys(&:to_s)
    end
    private_class_method :complete_counts_by_locale

    # Translation-table columns for the model's translatable fields, mapped from
    # the PUBLIC field names to the internal ones (OptionType exposes `label`,
    # the column is `presentation`).
    def internal_field_columns(klass)
      aliases = klass.translatable_field_aliases
      klass.public_translatable_fields.map { |field| (aliases[field] || field).to_s }
    end
    private_class_method :internal_field_columns

    # Soft-deleted translation rows must not count as coverage; only some
    # translation tables carry `deleted_at`.
    def translation_scope(klass)
      scope = klass::Translation.unscoped
      scope = scope.where(deleted_at: nil) if klass::Translation.column_names.include?('deleted_at')
      scope
    end
    private_class_method :translation_scope

    def foreign_key(klass)
      klass.reflect_on_association(:translations).foreign_key
    end
    private_class_method :foreign_key
  end
end
