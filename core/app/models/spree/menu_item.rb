module Spree
  class MenuItem < Spree::Base
    belongs_to :menu

    acts_as_nested_set dependent: :destroy

    before_save :reset_link_attributes

    after_save :touch_ancestors
    after_touch :touch_ancestors

    has_one_attached :image_asset

    # Not frozen so they can be added to
    ITEM_TYPE = %w[Link Promotion Container]

    LINKED_RESOURCE_TYPE = []
    STATIC_RESOURCE_TYPE = ['URL', 'Home Page']
    DYNAMIC_RESOURCE_TYPE = ['Product', 'Taxon']

    LINKED_RESOURCE_TYPE.unshift(*STATIC_RESOURCE_TYPE)
    LINKED_RESOURCE_TYPE.push(*DYNAMIC_RESOURCE_TYPE)

    validates :name, presence: true
    validates :item_type, inclusion: { in: ITEM_TYPE }
    validates :linked_resource_type, inclusion: { in: LINKED_RESOURCE_TYPE }

    def destination
      if DYNAMIC_RESOURCE_TYPE.include? linked_resource_type
        return if linked_resource_id.nil?

        case linked_resource_type
        when 'Taxon'
          permalink = Spree::Taxon.find(linked_resource_id).permalink || 'summer'
          Spree::Core::Engine.routes.url_helpers.nested_taxons_path(permalink)
        when 'Product'
          product = Spree::Product.find(linked_resource_id)
          Spree::Core::Engine.routes.url_helpers.product_path(product)
        end
      else
        case linked_resource_type
        when 'URL'
          url
        when 'Home Page'
          Spree::Core::Engine.routes.url_helpers.root_path
        end
      end
    end

    def child_index=(idx)
      move_to_child_with_index(parent, idx.to_i) unless new_record?
    end

    private

    def reset_link_attributes
      if linked_resource_type_changed?
        self.linked_resource_id = nil
        self.url = nil
      end
    end

    def touch_ancestors
      ancestors.update_all(updated_at: Time.current)
    end
  end
end
