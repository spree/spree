module Spree
  class MenuItem < Spree::Base
    acts_as_nested_set dependent: :destroy

    belongs_to :menu, touch: true
    belongs_to :linked_resource, polymorphic: true

    before_create :ensure_item_belongs_to_root
    before_save :reset_link_attributes, :paremeterize_code

    after_save :touch_ancestors_and_menu
    after_touch :touch_ancestors_and_menu

    ITEM_TYPE = %w[Link Container]

    LINKED_RESOURCE_TYPE = ['URL']
    STATIC_RESOURCE_TYPE = ['Home Page']
    DYNAMIC_RESOURCE_TYPE = ['Spree::Product', 'Spree::Taxon']

    LINKED_RESOURCE_TYPE.unshift(*STATIC_RESOURCE_TYPE)
    LINKED_RESOURCE_TYPE.push(*DYNAMIC_RESOURCE_TYPE)

    validates :name, presence: true
    validates :menu, presence: true
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

    def link
      case linked_resource_type
      when 'Spree::Taxon'
        return if linked_resource.nil?

        if frontend_available?
          Spree::Core::Engine.routes.url_helpers.nested_taxons_path(linked_resource.permalink)
        else
          "/#{Spree::Config[:storefront_taxons_path]}/#{linked_resource.permalink}"
        end
      when 'Spree::Product'
        return if linked_resource.nil?

        if frontend_available?
          Spree::Core::Engine.routes.url_helpers.product_path(linked_resource)
        else
          "/#{Spree::Config[:storefront_products_path]}/#{linked_resource.slug}"
        end
      when 'Home Page'
        '/'
      when 'URL'
        destination
      end
    end

    private

    def frontend_available?
      Spree::Core::Engine.frontend_available?
    end

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
