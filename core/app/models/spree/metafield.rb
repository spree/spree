module Spree
  class Metafield < Spree.base_class
    #
    # Associations
    #
    belongs_to :resource, polymorphic: true, touch: true
    belongs_to :metafield_definition, class_name: 'Spree::MetafieldDefinition'

    #
    # Delegations
    #
    delegate :key, :full_key, :name, :display_on, to: :metafield_definition, allow_nil: true

    #
    # Callbacks
    #
    before_validation :set_type_from_metafield_definition, on: :create

    #
    # Validations
    #
    validates :metafield_definition, :type, :resource, :value, presence: true
    validates :metafield_definition_id, uniqueness: { scope: [:resource_type, :resource_id] }
    validate :type_must_match_metafield_definition

    #
    # Scopes
    #
    scope :available_on_front_end, -> { joins(:metafield_definition).merge(Spree::MetafieldDefinition.available_on_front_end) }
    scope :available_on_back_end, -> { joins(:metafield_definition).merge(Spree::MetafieldDefinition.available_on_back_end) }
    scope :with_key, ->(namespace, key) { joins(:metafield_definition).where(spree_metafield_definitions: { namespace: namespace, key: key }) }

    def serialize_value
      value
    end

    def csv_value
      value.to_s
    end

    private

    def set_type_from_metafield_definition
      self.type ||= metafield_definition.metafield_type
    end

    def type_must_match_metafield_definition
      return if metafield_definition.blank?

      errors.add(:type, 'must match metafield definition') unless type == metafield_definition.metafield_type
    end
  end
end
