module Spree
  class CustomField < Spree.base_class
    # Map of API-facing tokens to Ruby STI class names. The wire format is the
    # token (`short_text`); the database column stores the class name. Reads
    # translate to the token via `field_type`; writes accept either form.
    # Plugin-defined types fall through to the raw class name until a
    # registration API lands.
    TYPE_TOKENS = {
      'short_text' => 'Spree::CustomFields::ShortText',
      'long_text'  => 'Spree::CustomFields::LongText',
      'rich_text'  => 'Spree::CustomFields::RichText',
      'number'     => 'Spree::CustomFields::Number',
      'boolean'    => 'Spree::CustomFields::Boolean',
      'json'       => 'Spree::CustomFields::Json',
      'date'       => 'Spree::CustomFields::Date',
      'date_time'  => 'Spree::CustomFields::DateTime',
      'choice'     => 'Spree::CustomFields::Choice'
    }.freeze
    TYPE_CLASS_TO_TOKEN = TYPE_TOKENS.invert.freeze

    # Array form consumed by serializers via
    # `typelize field_type: Spree::CustomField::FIELD_TYPE_TOKENS`. Typelizer
    # emits a string-literal union in TypeScript and `{type: string, enum: […]}`
    # in OpenAPI (string-array form was added in typelizer 0.10.0).
    FIELD_TYPE_TOKENS = TYPE_TOKENS.keys.freeze

    # Whether CustomFieldDefinition may enable `searchable` / `sortable` for
    # this STI type. Used only by definition validations (not by SearchProvider
    # indexing). Defaults to false; subclasses override (e.g. ShortText).
    def self.searchable?
      false
    end

    def self.sortable?
      false
    end

    # Rules a definition of this type may set in `validations`, besides
    # `required`, which every type takes.
    #
    # @return [Array<String>]
    def self.supported_validation_rules
      []
    end

    # The canonical form of a `min` / `max` rule, the one values are compared
    # against.
    #
    # @param value [Object] the bound as sent
    # @param store [Spree::Store, nil] the definition's store, for its time zone
    # @return [Object, nil] nil when the bound is not valid for this type
    def self.normalize_validation_bound(_value, store: nil)
      nil
    end

    # Rows are mostly built from a definition rather than a `type`
    # (`find_or_initialize_by(custom_field_definition_id:)`, nested
    # attributes), so the definition picks the typed subclass. Without it a new
    # row would skip its type's parsing and validations until it was reloaded.
    def self.subclass_from_attributes(attributes)
      super || (custom_field_class_from_definition(attributes) if base_class?)
    end
    private_class_method :subclass_from_attributes

    def self.custom_field_class_from_definition(attributes)
      attributes = attributes.to_h if attributes.respond_to?(:permitted?)
      return unless attributes.is_a?(Hash)

      attributes = attributes.with_indifferent_access
      definition = attributes[:custom_field_definition] ||
                   attributes[:custom_field_definition_id].presence&.then { |id| Spree::CustomFieldDefinition.find_by_param(id) }
      definition.try(:field_type_class)
    end
    private_class_method :custom_field_class_from_definition

    has_prefix_id :cf

    #
    # Associations
    #
    belongs_to :resource, polymorphic: true, touch: true
    belongs_to :custom_field_definition, class_name: 'Spree::CustomFieldDefinition'

    # API-facing form of the STI `type` column. Returns the token
    # (`short_text`) when the row's type is a registered built-in; falls
    # through to the raw class name for plugin types.
    #
    # `self[:type]` reads the raw column to bypass AR's STI reader (which
    # returns the resolved class constant, not a string).
    def field_type
      TYPE_CLASS_TO_TOKEN[self[:type]] || self[:type]
    end

    #
    # Delegations
    #
    delegate :key, :full_key, :label, :storefront_visible, to: :custom_field_definition, allow_nil: true

    #
    # Callbacks
    #
    before_validation :set_type_from_custom_field_definition, on: :create

    #
    # Validations
    #
    validates :type, :resource, :value, presence: true
    validates :custom_field_definition_id, uniqueness: { scope: [:resource_type, :resource_id] }
    validate :type_must_match_custom_field_definition
    validate :resource_type_must_match_custom_field_definition
    validate :custom_field_definition_must_belong_to_the_resource_store
    # New writes only: a value that met the rules when it was saved stays
    # readable after a rule changes, and is checked again when rewritten.
    validate :value_must_follow_definition_rules, if: -> { custom_field_definition && value.present? && (new_record? || will_save_change_to_value?) }

    #
    # Scopes
    #
    scope :storefront_visible, -> { joins(:custom_field_definition).merge(Spree::CustomFieldDefinition.storefront_visible) }
    scope :admin_only, -> { joins(:custom_field_definition).merge(Spree::CustomFieldDefinition.admin_only) }
    scope :with_key, ->(namespace, key) {
      joins(:custom_field_definition).
        where(Spree::CustomFieldDefinition.table_name => { namespace: namespace, key: key })
    }

    def serialize_value
      value
    end

    # The value as plain text, for exports and feeds that cannot carry
    # structure.
    def text_value
      value.to_s
    end

    def csv_value
      text_value
    end

    #
    # Deprecated 6.0 names, removed in 6.1
    #
    def metafield_definition
      Spree::Deprecation.warn('#metafield_definition is deprecated and will be removed in Spree 6.1. Use #custom_field_definition instead.')
      custom_field_definition
    end

    def metafield_definition_id
      Spree::Deprecation.warn('#metafield_definition_id is deprecated and will be removed in Spree 6.1. Use #custom_field_definition_id instead.')
      custom_field_definition_id
    end

    def metafield_definition_id=(value)
      Spree::Deprecation.warn('#metafield_definition_id= is deprecated and will be removed in Spree 6.1. Use #custom_field_definition_id= instead.')
      self.custom_field_definition_id = value
    end

    def metafield_definition=(value)
      Spree::Deprecation.warn('#metafield_definition= is deprecated and will be removed in Spree 6.1. Use #custom_field_definition= instead.')
      self.custom_field_definition = value
    end

    def name
      Spree::Deprecation.warn('#name is deprecated and will be removed in Spree 6.1. Use #label instead.')
      label
    end

    private

    # Types that take `min` / `max` or `choices` check the value here.
    def value_must_follow_definition_rules; end

    # @return [Hash{String => Object}]
    def definition_rules
      custom_field_definition.validation_rules
    end

    # Adds the `min` / `max` errors, comparing +comparable+ against each bound
    # as +bound+ reads it.
    def add_bound_errors(comparable, below:, above:, bound: :itself.to_proc)
      min, max = definition_rules.values_at('min', 'max')
      add_value_error(below, min) if min && comparable < bound.call(min)
      add_value_error(above, max) if max && comparable > bound.call(max)
    end

    def add_value_error(type, bound)
      errors.add(:value, type, bound: bound, message: I18n.t("spree.errors.messages.custom_field_#{type}", bound: bound))
    end

    def set_type_from_custom_field_definition
      return if custom_field_definition.blank?

      self.type ||= custom_field_definition.field_type_class_name
    end

    def type_must_match_custom_field_definition
      return if custom_field_definition.blank?

      unless type == custom_field_definition.field_type_class_name
        errors.add(:type, :custom_field_definition_mismatch,
                   message: I18n.t('spree.errors.messages.custom_field_definition_mismatch'))
      end
    end

    # A definition belongs to one resource type; attaching it to a different
    # one produces a row no lookup for either type would return. An STI row
    # stores its base class in the polymorphic column while the definition
    # names the subclass, so compare against the definition's base class too.
    def resource_type_must_match_custom_field_definition
      return if custom_field_definition.blank? || resource_type.blank?

      definition_type = custom_field_definition.resource_type
      return if resource_type == definition_type
      return if definition_type.safe_constantize&.base_class&.name == resource_type

      errors.add(:resource_type, :custom_field_definition_mismatch,
                 message: I18n.t('spree.errors.messages.custom_field_definition_mismatch'))
    end

    # Definitions are store-owned, so a record may only carry its own store's.
    # Rails' `custom_fields_attributes=` assigns the id straight onto the row
    # without passing the store-scoped resolver, so this is what covers it.
    # A global resource — a customer, an address — has no store_id and is
    # skipped: it can carry a field defined by any store it deals with.
    def custom_field_definition_must_belong_to_the_resource_store
      return if custom_field_definition.blank? || resource.try(:store_id).blank?
      return if custom_field_definition.store_id == resource.store_id

      errors.add(:custom_field_definition, :must_belong_to_same_store)
    end
  end
end
