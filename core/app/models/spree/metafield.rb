module Spree
  class Metafield < Spree.base_class
    #
    # Associations
    #
    belongs_to :resource, polymorphic: true
    belongs_to :metafield_definition, class_name: 'Spree::MetafieldDefinition'

    #
    # Delegations
    #
    delegate :key, :full_key, :name, :display_on, to: :metafield_definition, allow_nil: true

    #
    # Validations
    #
    validates :metafield_definition, :type, :resource, :value, presence: true
    validates :metafield_definition_id, uniqueness: { scope: [:resource_type, :resource_id] }

    #
    # Scopes
    #
    scope :available_on_front_end, -> { joins(:metafield_definition).merge(Spree::MetafieldDefinition.available_on_front_end) }
    scope :available_on_back_end, -> { joins(:metafield_definition).merge(Spree::MetafieldDefinition.available_on_back_end) }
    scope :with_key, ->(namespace, key) { joins(:metafield_definition).where(spree_metafield_definitions: { namespace: namespace, key: key }) }
  end
end
