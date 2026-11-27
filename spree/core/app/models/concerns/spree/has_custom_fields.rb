module Spree
  module HasCustomFields
    extend ActiveSupport::Concern

    # The most a shopper may write into one field, in characters.
    STOREFRONT_VALUE_MAX_LENGTH = 5_000

    module ClassMethods
      # @param key_with_namespace [String] the dotted `"namespace.key"` form
      # @param store [Spree::Store, nil] the store the definition belongs to;
      #   defaults to the current request's store, since definitions are
      #   store-owned and there is no global schema to fall back on.
      def ensure_custom_field_definition_exists!(key_with_namespace, store: Spree::Current.store)
        namespace, key = extract_namespace_and_key(key_with_namespace)
        raise ArgumentError, 'a store is required to create a custom field definition' if store.nil?

        store.custom_field_definitions.find_or_create_by!(
          namespace: namespace, key: key, resource_type: self.name
        )
      end

      # The resource type this model's definitions are declared under.
      #
      # @return [String]
      def custom_field_definition_resource_type
        name
      end

      def extract_namespace_and_key(key_with_namespace)
        namespace = key_with_namespace.to_s.split('.').first
        key = key_with_namespace.to_s.split('.').last
        [namespace, key]
      end

      # Deprecated 6.0 names, removed in 6.3.
      def ensure_metafield_definition_exists!(key_with_namespace, store: Spree::Current.store)
        Spree::Deprecation.warn(
          'ensure_metafield_definition_exists! is deprecated and will be removed in Spree 6.3. Use ensure_custom_field_definition_exists! instead.'
        )
        ensure_custom_field_definition_exists!(key_with_namespace, store: store)
      end

      def with_metafield_key(key_with_namespace)
        Spree::Deprecation.warn('.with_metafield_key is deprecated and will be removed in Spree 6.3. Use .with_custom_field_key instead.')
        with_custom_field_key(key_with_namespace)
      end

      def with_metafield_key_value(key_with_namespace, value)
        Spree::Deprecation.warn('.with_metafield_key_value is deprecated and will be removed in Spree 6.3. Use .with_custom_field_key_value instead.')
        with_custom_field_key_value(key_with_namespace, value)
      end
    end

    included do
      # The explicit inverse lets a custom field built on an unsaved owner find that owner when
      # it is saved. Rails cannot infer it for a scoped association, so without it the row is
      # inserted with a NULL resource_id unless the app happens to enable `has_many_inversing`.
      has_many :custom_fields, -> { includes(:custom_field_definition) }, as: :resource, inverse_of: :resource, class_name: 'Spree::CustomField', dependent: :destroy
      has_many :storefront_custom_fields, -> { includes(:custom_field_definition).storefront_visible }, as: :resource, class_name: 'Spree::CustomField'

      # Deprecated 6.0 association names, removed in 6.3. `private_metafields`
      # has no replacement — read `custom_fields` and filter, or query
      # Spree::CustomField.admin_only directly.
      has_many :metafields, -> { includes(:custom_field_definition) }, as: :resource, class_name: 'Spree::CustomField', deprecated: true
      has_many :public_metafields, -> { includes(:custom_field_definition).storefront_visible }, as: :resource, class_name: 'Spree::CustomField', deprecated: true
      has_many :private_metafields, -> { includes(:custom_field_definition).admin_only }, as: :resource, class_name: 'Spree::CustomField', deprecated: true

      accepts_nested_attributes_for :custom_fields, allow_destroy: true, reject_if: lambda { |attrs|
                                                                                     attrs[:custom_field_definition_id].blank? || (attrs[:id].blank? && attrs[:value].blank?)
                                                                                   }

      # Override custom_fields_attributes= to automatically mark existing custom fields
      # with empty values for destruction
      def custom_fields_attributes=(attributes)
        attributes = attributes.values if attributes.is_a?(Hash)

        attributes.each do |attrs|
          # If this is an existing custom field (has an id) and value is blank,
          # mark it for destruction
          if attrs[:id].present? && value_blank?(attrs[:value])
            attrs[:_destroy] = true
          end
        end

        super(attributes)
      end

      # Bulk writer reached via flat params on the admin API v3
      # (`custom_fields: [...]`); also works through
      # `Model.new(permitted_params)` since Rails routes the key to this writer.
      #
      # Upsert semantics by `custom_field_definition_id`: existing entries
      # for the same definition are updated, missing entries are created.
      # Partial: definitions NOT in the array are left untouched, so the
      # client can patch one field at a time without resending the rest.
      # Blank values on an existing custom field destroy it (mirrors the dedicated
      # endpoint's behavior via `custom_fields_attributes=`).
      def custom_fields=(attributes)
        return if attributes.blank?
        return super(attributes) if attributes.first.is_a?(Spree::CustomField)

        assign_custom_field_attrs(attributes)
      end

      after_save :apply_pending_custom_fields, if: -> { @pending_custom_field_attrs.present? }

      # Shopper writes from the Store API, as `[{ key: 'namespace.key', value: }]`.
      # Keys resolve only among this store's storefront-writable definitions
      # for the resource, and are never created. A blank value removes the
      # field; fields not named are left as they are.
      #
      # @param entries [Array<Hash>, nil]
      def storefront_custom_field_values=(entries)
        # A form-encoded list arrives keyed by position.
        entries = entries.to_h.values if entries.respond_to?(:to_h) && !entries.is_a?(Array)
        @storefront_custom_field_entries = Array(entries)
      end

      validate :storefront_custom_field_values_must_be_writable, unless: -> { @storefront_custom_field_entries.nil? }
      after_save :apply_storefront_custom_field_values, unless: -> { @storefront_custom_field_entries.nil? }

      # @return [ActiveRecord::Relation<Spree::CustomFieldDefinition>] the
      #   definitions a shopper may fill in on this record
      def storefront_writable_custom_field_definitions
        custom_field_definition_store.custom_field_definitions.storefront_writable.storefront_visible.
          for_resource_type(self.class.custom_field_definition_resource_type)
      end

      # The definitions this record has a value for. Read once per record, like
      # the required definitions, and forgotten whenever a value is written.
      #
      # @return [Array<Integer>]
      def filled_custom_field_definition_ids
        @filled_custom_field_definition_ids ||= if custom_fields.loaded?
                                                  custom_fields.map(&:custom_field_definition_id)
                                                else
                                                  custom_fields.unscope(:includes).pluck(:custom_field_definition_id)
                                                end
      end

      # Read once per record: every cart response works out its requirements
      # several times over.
      #
      # @return [Array<Spree::CustomFieldDefinition>]
      def required_storefront_writable_custom_field_definitions
        @required_storefront_writable_custom_field_definitions ||= storefront_writable_custom_field_definitions.select(&:required?)
      end

      scope :with_custom_field_key, ->(key_with_namespace) {
        namespace, key = extract_namespace_and_key(key_with_namespace)
        joins(custom_fields: :custom_field_definition).
          where(Spree::CustomFieldDefinition.table_name => { namespace: namespace, key: key })
      }
      scope :with_custom_field_key_value, ->(key_with_namespace, value) {
        namespace, key = extract_namespace_and_key(key_with_namespace)

        joins(custom_fields: :custom_field_definition)
          .where(Spree::CustomFieldDefinition.table_name => { namespace: namespace, key: key })
          .where(Spree::CustomField.table_name => { value: value })
      }

      def extract_namespace_and_key(key_with_namespace)
        self.class.extract_namespace_and_key(key_with_namespace)
      end

      # Upsert a single custom field value on this resource. The first
      # argument locates the definition by any of:
      #
      # - `"namespace.key"` string — auto-creates the definition if missing
      #   (backend-internal callers that don't know the id upfront).
      # - {Spree::CustomFieldDefinition} instance.
      # - Integer / numeric String — raw definition id.
      # - Prefixed-id String (`"cfdef_..."`) — decoded to the definition id.
      #
      # Blank values (nil or empty/whitespace string) destroy any existing
      # custom field for the definition. Empty containers (`[]`, `{}`) and
      # numeric / boolean falsy values are real values, not blanks.
      #
      # @param definition_or_key [String, Integer, Spree::CustomFieldDefinition]
      # @param value [Object] the value to persist; type is enforced by the
      #   typed custom-field subclass (Boolean, Number, Json, ShortText, …).
      # @return [Spree::CustomField, nil] the persisted custom field, or nil when
      #   the value was blank and any existing row was destroyed.
      # @raise [ArgumentError] if `definition_or_key` doesn't resolve to a
      #   known definition.
      def set_custom_field(definition_or_key, value)
        @filled_custom_field_definition_ids = nil
        definition_id = resolve_custom_field_definition_id(definition_or_key)
        custom_field = custom_fields.find_or_initialize_by(custom_field_definition_id: definition_id)
        # An empty list is a value for JSON, but no choice at all for a choice field.
        if value_blank?(value) || (value == [] && custom_field.is_a?(Spree::CustomFields::Choice))
          # Through the association, so a loaded list drops the row too.
          custom_fields.destroy(custom_field) if custom_field.persisted?
          return nil
        end

        custom_field.value = value
        custom_field.save!
        custom_field
      end

      # Copies another record's custom field values onto this one, as they are:
      # a copy is not a new write, so rules changed since are not applied.
      #
      # @param source [Spree::HasCustomFields] a cart completing into this order, or a sibling order
      # @return [void]
      def copy_custom_fields_from!(source)
        rows = source.custom_fields.unscope(:includes).pluck(:type, :custom_field_definition_id, :value).map do |type, definition_id, value|
          { type: type, custom_field_definition_id: definition_id, value: value, resource_type: self.class.polymorphic_name, resource_id: id }
        end
        return if rows.empty?

        Spree::CustomField.insert_all!(rows)
        reset_custom_fields
      end

      # Forgets the values read so far, after a bulk write that went around the association.
      #
      # @return [void]
      def reset_custom_fields
        custom_fields.reset
        storefront_custom_fields.reset
        @filled_custom_field_definition_ids = nil
      end

      def get_custom_field(key_with_namespace)
        namespace, key = extract_namespace_and_key(key_with_namespace)
        custom_fields.with_key(namespace, key).first
      end

      def has_custom_field?(key_with_namespace)
        if key_with_namespace.is_a?(Spree::CustomFieldDefinition)
          namespace = key_with_namespace.namespace
          key = key_with_namespace.key
        elsif key_with_namespace.is_a?(String)
          namespace, key = extract_namespace_and_key(key_with_namespace)
        else
          raise ArgumentError, "Invalid key_with_namespace: #{key_with_namespace.inspect}"
        end

        custom_fields.with_key(namespace, key).exists?
      end

      # Deprecated 6.0 names, removed in 6.3.
      def set_metafield(definition_or_key, value)
        Spree::Deprecation.warn('#set_metafield is deprecated and will be removed in Spree 6.3. Use #set_custom_field instead.')
        set_custom_field(definition_or_key, value)
      end

      def get_metafield(key_with_namespace)
        Spree::Deprecation.warn('#get_metafield is deprecated and will be removed in Spree 6.3. Use #get_custom_field instead.')
        get_custom_field(key_with_namespace)
      end

      def has_metafield?(key_with_namespace)
        Spree::Deprecation.warn('#has_metafield? is deprecated and will be removed in Spree 6.3. Use #has_custom_field? instead.')
        has_custom_field?(key_with_namespace)
      end

      # Legacy payloads key the definition as `metafield_definition_id`, which
      # the new writer rejects — translate rather than silently dropping them.
      def metafields_attributes=(attributes)
        Spree::Deprecation.warn('#metafields_attributes= is deprecated and will be removed in Spree 6.3. Use #custom_fields_attributes= instead.')

        attributes = attributes.values if attributes.is_a?(Hash)
        translated = attributes.map do |attrs|
          attrs = attrs.respond_to?(:to_h) ? attrs.to_h : attrs
          attrs = attrs.with_indifferent_access
          attrs[:custom_field_definition_id] ||= attrs.delete(:metafield_definition_id)
          attrs
        end

        self.custom_fields_attributes = translated
      end

      private

      # Decide whether a custom-field value should trigger the destroy-existing
      # branch. Ruby's `blank?` reports `false`, `0`, `[]`, `{}` as blank, but
      # for typed custom fields those are real values:
      #
      # - Boolean `false` / Numeric `0` — real values, never destroy.
      # - Empty Array / Hash — a JSON custom field storing `[]` or `{}` is a
      #   meaningful value (an empty list / object), not a clear signal.
      #
      # Only `nil` and empty/whitespace strings count as "missing".
      #
      # @param value [Object]
      # @return [Boolean]
      def value_blank?(value)
        return true if value.nil?
        return value.strip.empty? if value.is_a?(String)

        false
      end

      def assign_custom_field_attrs(attributes)
        if new_record?
          # Persisting custom_fields requires a persisted parent (resource_id NOT
          # NULL). Stash the attrs and replay them after the parent is saved.
          @pending_custom_field_attrs = attributes
          return
        end

        apply_custom_field_attrs(attributes)
      end

      def apply_pending_custom_fields
        attrs = @pending_custom_field_attrs
        @pending_custom_field_attrs = nil
        apply_custom_field_attrs(attrs)
      end

      def apply_custom_field_attrs(attributes)
        attributes = attributes.values if attributes.is_a?(Hash)
        attributes.each_with_index do |raw, index|
          attrs = raw.respond_to?(:to_h) ? raw.to_h : raw
          attrs = attrs.with_indifferent_access
          definition_id = attrs[:custom_field_definition_id] || attrs[:metafield_definition_id]
          next if definition_id.blank?

          write_custom_field_at!(index, definition_id, attrs[:value])
        end
      end

      # +index+ is the entry's position in the request, for the error key.
      def write_custom_field_at!(index, definition_or_key, value)
        set_custom_field(definition_or_key, value)
      rescue ArgumentError => e
        # Convert an unknown / malformed definition id into a field-level
        # validation error so the controller returns 422 with structured
        # `details`, instead of leaking ArgumentError as a 400/500.
        errors.add("custom_fields[#{index}].custom_field_definition_id", e.message)
        raise ActiveRecord::RecordInvalid, self
      rescue ActiveRecord::RecordInvalid => e
        # A value that breaks its definition's rules is reported on this
        # record, since `save` swallows the custom field's own error when
        # it is raised from the after_save replay.
        e.record.errors.each { |error| errors.add("custom_fields[#{index}].#{error.attribute}", error.message) }
        raise ActiveRecord::RecordInvalid, self
      end

      # Resolves the shopper's keys before anything is saved, so an unknown
      # key or a missing required value refuses the whole write.
      def storefront_custom_field_values_must_be_writable
        definitions = storefront_writable_custom_field_definitions.index_by(&:full_key)
        @resolved_storefront_custom_fields = []

        @storefront_custom_field_entries.each_with_index do |raw, index|
          entry = raw.respond_to?(:to_h) ? raw.to_h.with_indifferent_access : {}
          definition = definitions[entry[:key].to_s]

          # Messages rather than error types: generating a message from a type
          # reads the attribute, and these entries are no attribute of the record.
          if definition.nil?
            errors.add("custom_fields[#{index}].key", I18n.t('spree.errors.messages.custom_field_not_storefront_writable'))
          elsif @resolved_storefront_custom_fields.any? { |_index, resolved, _value| resolved == definition }
            # One entry per field, so a request writes each field once at most.
            errors.add("custom_fields[#{index}].key", I18n.t('spree.errors.messages.custom_field_named_twice'))
          elsif definition.required? && enforce_required_storefront_custom_fields? && storefront_value_missing?(entry[:value])
            errors.add("custom_fields[#{index}].value", I18n.t('spree.errors.messages.custom_field_blank'))
          elsif storefront_value_length(entry[:value]) > STOREFRONT_VALUE_MAX_LENGTH
            # Anyone with the publishable key can write here, so a value is
            # capped whatever rules the merchant set.
            errors.add("custom_fields[#{index}].value",
                       I18n.t('spree.errors.messages.custom_field_too_long', bound: STOREFRONT_VALUE_MAX_LENGTH))
          else
            @resolved_storefront_custom_fields << [index, definition, entry[:value]]
          end
        end

        add_missing_required_storefront_custom_field_errors(definitions.values) if new_record? && enforce_required_storefront_custom_fields?
      end

      # A new record has no values yet, so every required field must be named.
      def add_missing_required_storefront_custom_field_errors(definitions)
        named = @resolved_storefront_custom_fields.filter_map { |_index, definition, value| definition unless storefront_value_missing?(value) }

        (definitions.select(&:required?) - named).each do |definition|
          message = I18n.t('spree.errors.messages.custom_field_required_missing', label: definition.label)
          errors.add(:custom_fields, :required_missing, label: definition.label, message: message)
        end
      end

      # Characters of text, or of the list a multiple choice sends.
      def storefront_value_length(value)
        value.is_a?(String) ? value.length : value.to_json.length
      end

      # An empty list is no choice at all, which a required field cannot keep.
      def storefront_value_missing?(value)
        value_blank?(value) || value == []
      end

      def apply_storefront_custom_field_values
        resolved = @resolved_storefront_custom_fields || []
        @storefront_custom_field_entries = nil
        @resolved_storefront_custom_fields = nil

        resolved.each { |index, definition, value| write_custom_field_at!(index, definition, value) }
      end

      # Whether a shopper's write must keep this record's required fields.
      # An order's are a checkout requirement instead, so a cart overrides it.
      def enforce_required_storefront_custom_fields?
        true
      end

      # Resolve any of the supported reference shapes to a raw definition id.
      # See {#set_custom_field} for the accepted shapes.
      #
      # Every shape is checked against this record's store: definitions are
      # store-owned, so one store's record must not end up carrying another
      # store's definition whichever way the caller names it.
      #
      # @param definition_or_key [String, Integer, Spree::CustomFieldDefinition]
      # @return [Integer, String] the definition's primary key value (Integer
      #   for legacy integer-id setups, String for UUID setups).
      # @raise [ArgumentError] for unknown / malformed input, or a definition
      #   belonging to another store.
      def resolve_custom_field_definition_id(definition_or_key)
        case definition_or_key
        when Spree::CustomFieldDefinition
          # A loaded record already carries its store, so compare in memory
          # rather than paying a lookup to learn what is in hand.
          unless definition_or_key.store_id == custom_field_definition_store.id
            raise ArgumentError, "Unknown custom field definition id: #{definition_or_key.full_key.inspect}"
          end

          definition_or_key.id
        when Integer
          find_definition_id_in_store!(definition_or_key, definition_or_key)
        when String
          resolve_custom_field_definition_id_from_string(definition_or_key)
        else
          raise ArgumentError, "Invalid definition_or_key: #{definition_or_key.inspect}"
        end
      end

      # @param value [String] one of: `"namespace.key"`, a prefixed id
      #   (`"cfdef_..."`), or a bare numeric id (`"42"`).
      # @return [Integer, String] the resolved definition's primary key value.
      # @raise [ArgumentError] if the string doesn't match any known shape.
      def resolve_custom_field_definition_id_from_string(value)
        # `"namespace.key"` — backend-internal callers that don't know the id;
        # auto-create the definition if missing.
        if value.include?('.')
          return self.class.ensure_custom_field_definition_exists!(value, store: custom_field_definition_store).id
        end

        # Prefixed id (`"cfdef_..."`/`"mfd_..."`). Use the canonical predicate
        # so single-segment names with underscores (e.g. `"product_specs"`)
        # don't get mistaken for prefixed ids.
        #
        # Both id shapes are resolved through the store rather than the class.
        # That is what stops one store's record carrying another store's
        # definition, and it also covers the phantom-id case: Sqids will
        # happily decode any all-lowercase alphanumeric string to an integer
        # that matches no row, and without the existence check
        # `find_or_initialize_by(custom_field_definition_id: phantom_id)` would
        # later raise a confusing "CustomField definition must exist" 422
        # instead of an "unknown id" one.
        if Spree::PrefixedId.prefixed_id?(value)
          decoded = Spree::CustomFieldDefinition.decode_prefixed_id(value)
          return find_definition_id_in_store!(decoded, value)
        end

        # Bare numeric id ("42"). Reject anything else outright.
        raise ArgumentError, "Invalid custom field definition reference: #{value.inspect}" unless /\A\d+\z/.match?(value)

        find_definition_id_in_store!(value, value)
      end

      # @param id [Integer, String, nil] the decoded primary key
      # @param reference [String] what the caller passed, for the error message
      # @return [Integer, String] the definition's own primary key value
      # @raise [ArgumentError] when this store has no such definition.
      def find_definition_id_in_store!(id, reference)
        definition = id && custom_field_definition_store.custom_field_definitions.find_by(id: id)
        raise ArgumentError, "Unknown custom field definition id: #{reference.inspect}" if definition.nil?

        definition.id
      end

      # The store whose custom-field schema this record's fields are defined
      # in. A record that owns a store answers with it; one that reaches a
      # store through its owner overrides this (see Spree::Payment,
      # Spree::Variant); the genuinely global records — a customer, an
      # address — fall through to the current request's store, since their
      # fields still belong to one.
      #
      # Override rather than extending a chain here: which owner holds the
      # store is the host's own fact, and a chain of `try`s silently answers
      # for the wrong one when a host matches none of its steps.
      #
      # @return [Spree::Store]
      # @raise [ArgumentError] when none is available.
      def custom_field_definition_store
        store = try(:store) || Spree::Current.store
        raise ArgumentError, 'a store is required to resolve a custom field definition' if store.nil?

        store
      end
    end
  end
end
