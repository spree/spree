module Spree
  class MenuItem < Spree::Base
    include Spree::DisplayLink

    acts_as_nested_set dependent: :destroy

    belongs_to :menu, touch: true
    belongs_to :linked_resource, polymorphic: true

    before_create :ensure_item_belongs_to_root
    before_update :reset_link_attributes
    before_save :paremeterize_code

    after_save :touch_ancestors_and_menu
    after_touch :touch_ancestors_and_menu

    ITEM_TYPE = %w[Link Container]

    LINKED_RESOURCE_TYPE = ['URL']
    STATIC_RESOURCE_TYPE = ['Home Page']
    DYNAMIC_RESOURCE_TYPE = ['Spree::Product', 'Spree::Taxon', 'Spree::CmsPage']

    LINKED_RESOURCE_TYPE.unshift(*STATIC_RESOURCE_TYPE)
    LINKED_RESOURCE_TYPE.push(*DYNAMIC_RESOURCE_TYPE)

    validates :name, :menu, presence: true
    validates :item_type, inclusion: { in: ITEM_TYPE }
    validates :linked_resource_type, inclusion: { in: LINKED_RESOURCE_TYPE }

    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::Icon'
    accepts_nested_attributes_for :icon, reject_if: :all_blank

    def container?
      item_type == 'Container'
    end

    def code?(item_code = nil)
      if item_code
        code == item_code
      else
        code.present?
      end
    end

    private

    def reset_link_attributes
      if linked_resource_type_changed? || item_type == 'Container'
        self.linked_resource_id = nil
        self.destination = nil
        self.new_window = false

        self.linked_resource_type = 'URL' if item_type == 'Container'
      end
    end

    def ensure_item_belongs_to_root
      if menu.try(:root).present? && parent_id.nil?
        self.parent = menu.root

        store_new_parent
      end
    end

    def touch_ancestors_and_menu
      ancestors.update_all(updated_at: Time.current)
      menu.try!(:touch)
    end

    def paremeterize_code
      return if code.blank?

      self.code = code.parameterize
    end
  end
end
