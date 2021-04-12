module Spree
  class MenuItem < Spree::Base
    belongs_to :menu

    acts_as_nested_set dependent: :destroy

    after_save :touch_ancestors
    after_touch :touch_ancestors

    has_one_attached :image_asset

    # Not frozen so they can be added to
    ITEM_TYPE = %w[Link Promotion]
    LINKED_RESOURCE_TYPE = []
    STATIC_RESOURCE_TYPE = ['URL', 'Home Page']
    DYNAMIC_RESOURCE_TYPE = ['Spree::Product', 'Spree::Taxon', 'Spree::Page']

    LINKED_RESOURCE_TYPE.unshift(*STATIC_RESOURCE_TYPE)
    LINKED_RESOURCE_TYPE.push(*DYNAMIC_RESOURCE_TYPE)

    validates :name, presence: true
    validates :item_type, inclusion: { in: ITEM_TYPE }
    validates :linked_resource_type, inclusion: { in: LINKED_RESOURCE_TYPE }

    def cached_self_and_descendants_ids
      Rails.cache.fetch("#{cache_key_with_version}/descendant-ids") do
        self_and_descendants.ids
      end
    end

    def cached_self_and_descendants
      Rails.cache.fetch("#{cache_key_with_version}/descendant-ids") do
        self_and_descendants
      end
    end

    private

    def touch_ancestors
      ancestors.update_all(updated_at: Time.current)
    end
  end
end
