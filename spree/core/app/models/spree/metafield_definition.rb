module Spree
  class MetafieldDefinition < Spree.base_class
    has_prefix_id :cfdef

    include Spree::DisplayOn

    DISPLAY = [:both, :back_end]

    #
    # Associations
    #
    has_many :metafields, class_name: 'Spree::Metafield', dependent: :destroy

    #
    # Validations
    #
    validates :namespace, :key, :name, :resource_type, presence: true
    validates :metafield_type, presence: true, inclusion: { in: :valid_available_types }
    validates :resource_type, presence: true, inclusion: { in: :valid_available_resources }
    validates :key, uniqueness: { scope: spree_base_uniqueness_scope + [:resource_type, :namespace] }
    validate :field_type_input_must_be_recognized

    #
    # Scopes
    #
    scope :for_resource_type, ->(resource_type) { where(resource_type: resource_type) }
    scope :search, ->(query) do
      return all if query.blank?

      search_term = "%#{query.downcase}%"
      namespace_condition = arel_table[:namespace].lower.matches(search_term)
      key_condition = arel_table[:key].lower.matches(search_term)
      name_condition = arel_table[:name].lower.matches(search_term)

      where(namespace_condition.or(key_condition).or(name_condition))
    end

    # Backward compatibility alias — remove in Spree 6.0
    scope :multi_search, ->(*args) { search(*args) }

    #
    # Callbacks
    #
    normalizes :key, with: ->(value) { value.to_s.parameterize.underscore.strip }
    normalizes :namespace, with: ->(value) { value.to_s.parameterize.underscore.strip }
    before_validation :set_default_type, if: -> { metafield_type.blank? }, on: :create
    before_validation :set_name_from_key, if: -> { name.blank? }, on: :create

    #
    # Ransack
    #
    self.whitelisted_ransackable_attributes = %w[key namespace name resource_type display_on]
    self.whitelisted_ransackable_scopes = %w[search multi_search]

    # API naming bridge — internal columns rename in 6.0. `label` matches
    # OptionType/OptionValue conventions. (`storefront_visible` lives on
    # the `Spree::DisplayOn` concern, shared with PaymentMethod + ShippingMethod —
    # see docs/plans/5.5-6.0-display-on-to-boolean.md.)
    alias_attribute :label, :name

    # API-facing token for the STI subclass name stored in `metafield_type`.
    # Reader returns the registered token (`short_text`); writer accepts either
    # the token or the legacy class-name form for back-compat.
    def field_type
      Spree::Metafield::TYPE_CLASS_TO_TOKEN[metafield_type] || metafield_type
    end

    def field_type=(value)
      v = value.to_s
      mapped = Spree::Metafield::TYPE_TOKENS[v]
      # An input is "recognized" when it's either a known token (mapped to a
      # class) or already a known class name. Anything else gets surfaced as
      # an error on `field_type` so API clients get a token-vocabulary
      # message instead of the raw class-name inclusion error on
      # `metafield_type`.
      @field_type_input_recognized = !mapped.nil? || Spree::Metafield::TYPE_CLASS_TO_TOKEN.key?(v)
      self.metafield_type = mapped || value
    end

    # Returns the full key with namespace
    # @return [String] eg. custom.id
    def full_key
      "#{namespace}.#{key}"
    end

    # Returns the CSV header name for this metafield
    # @return [String] eg. metafield.custom.id
    def csv_header_name
      "metafield.#{full_key}"
    end

    # Returns the available types
    # @return [Array<Class>]
    def self.available_types
      Spree.metafields.types
    end

    # Returns the available resources
    # @return [Array<Class>]
    def self.available_resources
      Spree.metafields.enabled_resources
    end

    private

    def valid_available_types
      self.class.available_types.map(&:to_s)
    end

    def field_type_input_must_be_recognized
      return if @field_type_input_recognized.nil? || @field_type_input_recognized

      tokens = Spree::Metafield::TYPE_TOKENS.keys.join(', ')
      errors.add(:field_type, "is not a known custom field type (expected one of: #{tokens})")
    end

    def valid_available_resources
      self.class.available_resources.map(&:to_s)
    end

    def set_default_type
      self.metafield_type ||= Spree.metafields.types.first.to_s
    end

    def set_name_from_key
      self.name ||= key.titleize
    end
  end
end
