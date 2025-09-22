module Spree
  class Metafield < Spree.base_class
    #
    # Associations
    #
    belongs_to :owner, polymorphic: true
    belongs_to :metafield_definition, class_name: 'Spree::MetafieldDefinition'

    #
    # Validations
    #
    validates :metafield_definition, :owner, :value, presence: true
    validates :metafield_definition_id, uniqueness: { scope: [:owner_type, :owner_id] }

    #
    # Scopes
    #
    scope :available_on_front_end, -> { joins(:metafield_definition).merge(Spree::MetafieldDefinition.available_on_front_end) }
    scope :available_on_back_end, -> { joins(:metafield_definition).merge(Spree::MetafieldDefinition.available_on_back_end) }
    scope :with_key, ->(key) { joins(:metafield_definition).where(spree_metafield_definitions: { key: key }) }

    delegate :key, :kind, :name, :display_on, to: :metafield_definition, allow_nil: true
  end
end
