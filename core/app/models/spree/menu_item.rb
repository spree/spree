module Spree
  class MenuItem < Spree::Base
    include Spree::Core::Engine.routes.url_helpers

    belongs_to :menu
    belongs_to :linked_resource, polymorphic: true

    acts_as_nested_set dependent: :destroy

    before_save :reset_link_attributes

    after_save :touch_ancestors
    after_touch :touch_ancestors

    has_one_attached :image_asset

    # Not frozen so they can be added to
    ITEM_TYPE = %w[Link Promotion Container]

    LINKED_RESOURCE_TYPE = []
    STATIC_RESOURCE_TYPE = ['URL', 'Home Page']
    DYNAMIC_RESOURCE_TYPE = ['Spree::Product', 'Spree::Taxon']

    LINKED_RESOURCE_TYPE.unshift(*STATIC_RESOURCE_TYPE)
    LINKED_RESOURCE_TYPE.push(*DYNAMIC_RESOURCE_TYPE)

    validates :name, presence: true
    validates :item_type, inclusion: { in: ITEM_TYPE }
    validates :linked_resource_type, inclusion: { in: LINKED_RESOURCE_TYPE }

    def destination
      if DYNAMIC_RESOURCE_TYPE.include? linked_resource_type
        return if linked_resource.nil?

        case linked_resource_type
        when 'Spree::Taxon'
          nested_taxons_path(linked_resource.permalink)
        when 'Spree::Product'
          product_path(linked_resource)
        end
      else
        case linked_resource_type
        when 'URL'
          url
        when 'Home Page'
          root_path
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
