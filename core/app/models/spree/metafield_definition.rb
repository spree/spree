module Spree
  class MetafieldDefinition < Spree.base_class
    include Spree::DisplayOn

    # TODO: move this into engine config
    AVAILABLE_KINDS = %w[short_text long_text number boolean json rich_text].freeze

    #
    # Associations
    #
    has_many :metafields, class_name: 'Spree::Metafield', dependent: :destroy

    #
    # Validations
    #
    validates :key, :name, :owner_type, presence: true
    validates :kind, presence: true, inclusion: { in: AVAILABLE_KINDS }
    validates :key, uniqueness: { scope: spree_base_uniqueness_scope.push(:owner_type) }

    #
    # Scopes
    #
    scope :for_owner_type, ->(owner_type) { where(owner_type: owner_type) }


    #
    # Ransack
    #
    self.whitelisted_ransackable_attributes = %w[key name owner_type kind display_on]
  end
end
