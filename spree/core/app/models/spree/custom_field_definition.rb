module Spree
  class CustomFieldDefinition < Spree.base_class
    has_prefix_id :cfdef

    include Spree::CustomFieldDefinition::SearchCapabilities

    #
    # Associations
    #
    has_many :custom_fields, class_name: 'Spree::CustomField', dependent: :destroy

    #
    # Validations
    #
    validates :namespace, :key, :label, :resource_type, presence: true
    validates :resource_type, presence: true, inclusion: { in: :valid_available_resources }
    validates :key, uniqueness: { scope: spree_base_uniqueness_scope + [:resource_type, :namespace] }
    validate :field_type_input_must_be_recognized
    validate :field_type_must_be_available

    #
    # Scopes
    #
    scope :for_resource_type, ->(resource_type) { where(resource_type: resource_type) }
    scope :storefront_visible, -> { where(storefront_visible: true) }
    scope :admin_only, -> { where(storefront_visible: false) }
    scope :search, ->(query) do
      return all if query.blank?

      search_term = "%#{query.downcase}%"
      namespace_condition = arel_table[:namespace].lower.matches(search_term)
      key_condition = arel_table[:key].lower.matches(search_term)
      label_condition = arel_table[:label].lower.matches(search_term)

      where(namespace_condition.or(key_condition).or(label_condition))
    end

    #
    # Callbacks
    #
    normalizes :key, with: ->(value) { value.to_s.parameterize.underscore.strip }
    normalizes :namespace, with: ->(value) { value.to_s.parameterize.underscore.strip }
    before_validation :set_default_type, if: -> { self[:field_type].blank? }, on: :create
    before_validation :set_label_from_key, if: -> { label.blank? }, on: :create

    #
    # Ransack
    #
    self.whitelisted_ransackable_attributes = %w[key namespace label resource_type storefront_visible searchable sortable]
    self.whitelisted_ransackable_scopes = %w[search]

    # API-facing token for the STI subclass name stored in the `field_type`
    # column. Reader returns the registered token (`short_text`); writer
    # accepts either the token or the class-name form, which is what the
    # column itself holds.
    def field_type
      Spree::CustomField::TYPE_CLASS_TO_TOKEN[self[:field_type]] || self[:field_type]
    end

    def field_type=(value)
      string_value = value.to_s
      mapped = Spree::CustomField::TYPE_TOKENS[string_value]
      # An input is "recognized" when it's either a known token (mapped to a
      # class) or already a known class name. Anything else gets surfaced as
      # an error on `field_type` so API clients get a token-vocabulary
      # message instead of a raw class-name inclusion error.
      @field_type_input_recognized = !mapped.nil? || Spree::CustomField::TYPE_CLASS_TO_TOKEN.key?(string_value)
      super(mapped || value)
    end

    # The raw STI class name stored in the column, as opposed to the API token
    # returned by {#field_type}.
    # @return [String]
    def field_type_class_name
      self[:field_type]
    end

    #
    # Deprecated 6.0 column names, removed in 6.1
    #
    def name
      Spree::Deprecation.warn('#name is deprecated and will be removed in Spree 6.1. Use #label instead.')
      label
    end

    def name=(value)
      Spree::Deprecation.warn('#name= is deprecated and will be removed in Spree 6.1. Use #label= instead.')
      self.label = value
    end

    def metafield_type
      Spree::Deprecation.warn('#metafield_type is deprecated and will be removed in Spree 6.1. Use #field_type (which returns an API token) or #field_type_class_name instead.')
      field_type_class_name
    end

    def metafield_type=(value)
      Spree::Deprecation.warn('#metafield_type= is deprecated and will be removed in Spree 6.1. Use #field_type= instead.')
      self.field_type = value
    end

    # The tri-state display_on collapsed into the storefront_visible boolean;
    # 'front_end' folds into visible since it never meant hidden-from-storefront.
    def display_on
      Spree::Deprecation.warn('#display_on is deprecated and will be removed in Spree 6.1. Use #storefront_visible instead.')
      storefront_visible? ? 'both' : 'back_end'
    end

    def display_on=(value)
      Spree::Deprecation.warn('#display_on= is deprecated and will be removed in Spree 6.1. Use #storefront_visible= instead.')
      self.storefront_visible = value.to_s != 'back_end'
    end

    # Returns the full key with namespace
    # @return [String] eg. custom.id
    def full_key
      "#{namespace}.#{key}"
    end

    # Returns the CSV header name for this custom field
    # @return [String] eg. custom_field.custom.id
    def csv_header_name
      "custom_field.#{full_key}"
    end

    # Returns the available types
    # @return [Array<Class>]
    def self.available_types
      Spree.custom_fields.types
    end

    # Returns the available resources
    # @return [Array<Class>]
    def self.available_resources
      Spree.custom_fields.enabled_resources
    end

    private

    def valid_available_types
      self.class.available_types.map(&:to_s)
    end

    def field_type_input_must_be_recognized
      return if @field_type_input_recognized.nil? || @field_type_input_recognized

      tokens = Spree::CustomField::TYPE_TOKENS.keys.join(', ')
      errors.add(:field_type, "is not a known custom field type (expected one of: #{tokens})")
    end

    # Validates the stored class name, not the token the reader returns.
    def field_type_must_be_available
      class_name = field_type_class_name
      return errors.add(:field_type, :blank) if class_name.blank?
      return if valid_available_types.include?(class_name)

      errors.add(:field_type, :inclusion)
    end

    def valid_available_resources
      self.class.available_resources.map(&:to_s)
    end

    def set_default_type
      self[:field_type] ||= Spree.custom_fields.types.first.to_s
    end

    def set_label_from_key
      self.label ||= key.titleize
    end
  end
end
