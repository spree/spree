module Spree
  class MenuItem < Spree::Base
    belongs_to :menu

    # Not frozen so they can be added to
    ITEM_TYPE = %w[Link Promotion]
    LINKED_RESOURCE_TYPE = ['Home Page']
    STATIC_RESOURCE_TYPE = ['URL']
    DYNAMIC_RESOURCE_TYPE = ['Spree::Product', 'Spree::Taxon', 'Spree::Page']

    LINKED_RESOURCE_TYPE.unshift(*STATIC_RESOURCE_TYPE)
    LINKED_RESOURCE_TYPE.push(*DYNAMIC_RESOURCE_TYPE)

    validates :name, presence: true
    validates :item_type, inclusion: { in: ITEM_TYPE }
    validates :linked_resource_type, inclusion: { in: LINKED_RESOURCE_TYPE }
  end
end
