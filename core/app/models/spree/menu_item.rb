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

    ITEM_TYPE = %w[Link Promotion Container]

    LINKED_RESOURCE_TYPE = ['URL']
    STATIC_RESOURCE_TYPE = ['Home Page']
    DYNAMIC_RESOURCE_TYPE = ['Spree::Product', 'Spree::Taxon']

    if defined?(Spree::Frontend)
      LINKED_RESOURCE_TYPE.unshift(*STATIC_RESOURCE_TYPE)
      LINKED_RESOURCE_TYPE.push(*DYNAMIC_RESOURCE_TYPE)
    end

    validates :name, presence: true
    validates :menu_id, presence: true, numericality: { only_integer: true }
    validates :item_type, inclusion: { in: ITEM_TYPE }
    validates :linked_resource_type, inclusion: { in: LINKED_RESOURCE_TYPE }

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
