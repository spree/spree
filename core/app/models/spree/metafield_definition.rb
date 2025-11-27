module Spree
  class MetafieldDefinition < Spree.base_class
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

    #
    # Scopes
    #
    scope :for_resource_type, ->(resource_type) { where(resource_type: resource_type) }
    scope :multi_search, ->(search) do
      return all if search.blank?

      search_term = "%#{search.downcase}%"
      namespace_condition = arel_table[:namespace].lower.matches(search_term)
      key_condition = arel_table[:key].lower.matches(search_term)
      name_condition = arel_table[:name].lower.matches(search_term)

      where(namespace_condition.or(key_condition).or(name_condition))
    end

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
    self.whitelisted_ransackable_scopes = %w[multi_search]

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
