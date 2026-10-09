module Spree
  class CustomFieldDefinition < Spree.base_class
    has_prefix_id :cfdef

    include Spree::SingleStoreResource
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
    validates :key, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id, :resource_type, :namespace] }
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
    # The API names resources by shorthand (`product`); the column keeps the
    # class name the custom fields themselves are stored under. Also applies to
    # `where(resource_type:)`, so finders accept either.
    normalizes :resource_type, with: ->(value) { Spree::Base.polymorphic_type_for(value, available_resources) || value }
    normalizes :key, with: ->(value) { value.to_s.parameterize.underscore.strip }
    normalizes :namespace, with: ->(value) { value.to_s.parameterize.underscore.strip }
    before_validation :set_default_type, if: -> { self[:field_type].blank? }, on: :create
    before_validation :set_label_from_key, if: -> { label.blank? }, on: :create
    before_validation :set_filter_key

    #
    # Ransack
    #
    self.whitelisted_ransackable_attributes = %w[key namespace label resource_type field_type storefront_visible searchable sortable]

    # Both columns store class names; filters take the short names clients see.
    def self.api_type_resolver(attribute)
      case attribute
      when 'resource_type' then ->(api_type) { normalize_value_for(:resource_type, api_type) }
      when 'field_type' then ->(api_type) { Spree::CustomField::TYPE_TOKENS[api_type] }
      else super
      end
    end
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
      # An input is "recognized" when it's a known token (mapped to a class) or
      # any registered class name — extensions register their own types, which
      # have no token. Anything else gets surfaced as an error on `field_type`
      # so API clients get a token-vocabulary message instead of a raw
      # class-name inclusion error.
      @field_type_input_recognized = !mapped.nil? || valid_available_types.include?(string_value)
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

    # What a definition can be attached to: every registered resource, named
    # as the API names it, so a client renders a picker rather than carrying
    # its own list that drifts from the registry.
    #
    # @return [Array<Hash{Symbol => String}>] `resource_type` shorthand + `name`
    def self.enabled_resource_types
      # Through `available_resources`, not the registry directly: that is the
      # accessor the rest of the class reads, so discovery and validation
      # cannot disagree about what a host app has made available.
      Array(available_resources).compact.map do |resource|
        { resource_type: Spree::Base.polymorphic_api_type(resource), name: resource.to_s.demodulize.titleize.pluralize }
      end.uniq { |entry| entry[:resource_type] }.sort_by { |entry| entry[:name] }
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
      errors.add(:field_type, :unknown_custom_field_type, types: tokens,
                 message: I18n.t('spree.errors.messages.unknown_custom_field_type', types: tokens))
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

    # Kept in step with namespace and key, so renaming either moves the
    # sort/filter identifier with it rather than leaving a stale one that no
    # listing can address.
    #
    # A stored value is left alone while both segments stay put. Two splits can
    # flatten to one key, and the upgrade migration resolves such a pair by
    # suffixing the later row; recomputing on an unrelated edit would undo that
    # and leave the row permanently unsaveable.
    def set_filter_key
      return if self[:filter_key].present? && !namespace_changed? && !key_changed?

      self.filter_key = computed_filter_key
    end
  end
end
