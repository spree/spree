module Spree
  module HasCustomFields
    extend ActiveSupport::Concern

    module ClassMethods
      def ensure_custom_field_definition_exists!(key_with_namespace)
        namespace, key = extract_namespace_and_key(key_with_namespace)
        Spree::CustomFieldDefinition.find_or_create_by!(namespace: namespace, key: key, resource_type: self.name)
      end

      def extract_namespace_and_key(key_with_namespace)
        namespace = key_with_namespace.to_s.split('.').first
        key = key_with_namespace.to_s.split('.').last
        [namespace, key]
      end

      # Deprecated 6.0 names, removed in 6.1.
      def ensure_metafield_definition_exists!(key_with_namespace)
        Spree::Deprecation.warn('ensure_metafield_definition_exists! is deprecated and will be removed in Spree 6.1. Use ensure_custom_field_definition_exists! instead.')
        ensure_custom_field_definition_exists!(key_with_namespace)
      end

      def with_metafield_key(key_with_namespace)
        Spree::Deprecation.warn('.with_metafield_key is deprecated and will be removed in Spree 6.1. Use .with_custom_field_key instead.')
        with_custom_field_key(key_with_namespace)
      end

      def with_metafield_key_value(key_with_namespace, value)
        Spree::Deprecation.warn('.with_metafield_key_value is deprecated and will be removed in Spree 6.1. Use .with_custom_field_key_value instead.')
        with_custom_field_key_value(key_with_namespace, value)
      end
    end

    included do
      has_many :custom_fields, -> { includes(:custom_field_definition) }, as: :resource, class_name: 'Spree::CustomField', dependent: :destroy
      has_many :storefront_custom_fields, -> { includes(:custom_field_definition).storefront_visible }, as: :resource, class_name: 'Spree::CustomField'

      # Deprecated 6.0 association names, removed in 6.1. `private_metafields`
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
        definition_id = resolve_custom_field_definition_id(definition_or_key)
        custom_field = custom_fields.find_or_initialize_by(custom_field_definition_id: definition_id)
        if value_blank?(value)
          custom_field.destroy if custom_field.persisted?
          return nil
        end

        # JSON custom fields store canonical JSON in the underlying text column.
        # Coerce Hash/Array values BEFORE assignment, since the STI subclass
        # (`Spree::CustomFields::Json`) isn't switched on until before_validation,
        # so its custom `value=` writer doesn't run yet on a fresh
        # `find_or_initialize_by` record.
        if (value.is_a?(Hash) || value.is_a?(Array)) &&
           custom_field.custom_field_definition&.field_type == 'json'
          value = value.to_json
        end

        custom_field.value = value
        custom_field.save!
        custom_field
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

      # Deprecated 6.0 names, removed in 6.1.
      def set_metafield(definition_or_key, value)
        Spree::Deprecation.warn('#set_metafield is deprecated and will be removed in Spree 6.1. Use #set_custom_field instead.')
        set_custom_field(definition_or_key, value)
      end

      def get_metafield(key_with_namespace)
        Spree::Deprecation.warn('#get_metafield is deprecated and will be removed in Spree 6.1. Use #get_custom_field instead.')
        get_custom_field(key_with_namespace)
      end

      def has_metafield?(key_with_namespace)
        Spree::Deprecation.warn('#has_metafield? is deprecated and will be removed in Spree 6.1. Use #has_custom_field? instead.')
        has_custom_field?(key_with_namespace)
      end

      # Legacy payloads key the definition as `metafield_definition_id`, which
      # the new writer rejects — translate rather than silently dropping them.
      def metafields_attributes=(attributes)
        Spree::Deprecation.warn('#metafields_attributes= is deprecated and will be removed in Spree 6.1. Use #custom_fields_attributes= instead.')

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

          begin
            set_custom_field(definition_id, attrs[:value])
          rescue ArgumentError => e
            # Convert an unknown / malformed definition id into a field-level
            # validation error so the controller returns 422 with structured
            # `details`, instead of leaking ArgumentError as a 400/500.
            errors.add("custom_fields[#{index}].custom_field_definition_id", e.message)
            raise ActiveRecord::RecordInvalid, self
          end
        end
      end

      # Resolve any of the supported reference shapes to a raw definition id.
      # See {#set_custom_field} for the accepted shapes.
      #
      # @param definition_or_key [String, Integer, Spree::CustomFieldDefinition]
      # @return [Integer, String] the definition's primary key value (Integer
      #   for legacy integer-id setups, String for UUID setups).
      # @raise [ArgumentError] for unknown / malformed input.
      def resolve_custom_field_definition_id(definition_or_key)
        case definition_or_key
        when Spree::CustomFieldDefinition
          definition_or_key.id
        when Integer
          definition_or_key
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
          namespace, key = extract_namespace_and_key(value)
          return Spree::CustomFieldDefinition.find_or_create_by!(
            namespace: namespace, key: key, resource_type: self.class.name
          ).id
        end

        # Prefixed id (`"cfdef_..."`/`"mfd_..."`). Use the canonical predicate
        # so single-segment names with underscores (e.g. `"product_specs"`)
        # don't get mistaken for prefixed ids. We must verify the decoded id
        # actually exists — Sqids will happily decode any all-lowercase
        # alphanumeric string to a phantom integer; without the existence
        # check `find_or_initialize_by(custom_field_definition_id: phantom_id)`
        # would later raise a confusing "CustomField definition must exist"
        # 422 instead of an "unknown id" 422.
        if Spree::PrefixedId.prefixed_id?(value)
          decoded = Spree::CustomFieldDefinition.decode_prefixed_id(value)
          existing = decoded && Spree::CustomFieldDefinition.find_by(id: decoded)
          raise ArgumentError, "Unknown custom field definition id: #{value.inspect}" if existing.nil?

          return existing.id
        end

        # Bare numeric id ("42"). Reject anything else outright. Returned as
        # the original string — casting would rewrite zero-padded ids.
        raise ArgumentError, "Invalid custom field definition reference: #{value.inspect}" unless /\A\d+\z/.match?(value)

        value
      end
    end
  end
end
