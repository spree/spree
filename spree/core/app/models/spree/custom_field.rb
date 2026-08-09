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
      'json'       => 'Spree::CustomFields::Json'
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
    validates :custom_field_definition, :type, :resource, :value, presence: true
    validates :custom_field_definition_id, uniqueness: { scope: [:resource_type, :resource_id] }
    validate :type_must_match_custom_field_definition

    #
    # Scopes
    #
    scope :storefront_visible, -> { joins(:custom_field_definition).merge(Spree::CustomFieldDefinition.storefront_visible) }
    scope :admin_only, -> { joins(:custom_field_definition).merge(Spree::CustomFieldDefinition.admin_only) }
    scope :with_key, ->(namespace, key) { joins(:custom_field_definition).where(spree_custom_field_definitions: { namespace: namespace, key: key }) }

    def serialize_value
      value
    end

    def csv_value
      value.to_s
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

    def name
      Spree::Deprecation.warn('#name is deprecated and will be removed in Spree 6.1. Use #label instead.')
      label
    end

    private

    def set_type_from_custom_field_definition
      return if custom_field_definition.blank?

      self.type ||= custom_field_definition.field_type_class_name
    end

    def type_must_match_custom_field_definition
      return if custom_field_definition.blank?

      errors.add(:type, 'must match custom field definition') unless type == custom_field_definition.field_type_class_name
    end
  end
end
