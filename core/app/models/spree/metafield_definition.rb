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
    validates :key, :name, :resource_type, presence: true
    validates :kind, presence: true, inclusion: { in: AVAILABLE_KINDS }
    validates :key, uniqueness: { scope: spree_base_uniqueness_scope.push(:resource_type) }

    #
    # Scopes
    #
    scope :for_resource_type, ->(resource_type) { where(resource_type: resource_type) }

    #
    # Ransack
    #
    self.whitelisted_ransackable_attributes = %w[key name resource_type kind display_on]
  end
end
