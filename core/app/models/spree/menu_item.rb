module Spree
  class MenuItem < Spree::Base
    belongs_to :menu
    belongs_to :linked_resource, polymorphic: true

    acts_as_nested_set dependent: :destroy

    before_save :reset_link_attributes, :build_path, :paremeterize_code

    ITEM_TYPE = %w[Link Promotion Container]

    LINKED_RESOURCE_TYPE = ['URL']
    STATIC_RESOURCE_TYPE = ['Home Page']
    DYNAMIC_RESOURCE_TYPE = ['Spree::Product', 'Spree::Taxon']

    LINKED_RESOURCE_TYPE.unshift(*STATIC_RESOURCE_TYPE)
    LINKED_RESOURCE_TYPE.push(*DYNAMIC_RESOURCE_TYPE)

    validates :name, presence: true
    validates :menu, presence: true
    validates :item_type, inclusion: { in: ITEM_TYPE }
    validates :linked_resource_type, inclusion: { in: LINKED_RESOURCE_TYPE }
    validate :check_for_root, on: :create

    has_one :menu_item_image, as: :viewable, dependent: :destroy, class_name: 'Spree::MenuItemImage'
    accepts_nested_attributes_for :menu_item_image, reject_if: :all_blank

    def self.refresh_paths(resorce)
      where(linked_resource_type: resorce.class.name, linked_resource_id: resorce.id).each(&:save!)
    end

    private

    def build_path
      case linked_resource_type
      when 'Spree::Taxon'
        return if linked_resource.nil?

        self.destination = if frontend_available?
                             Spree::Core::Engine.routes.url_helpers.nested_taxons_path(linked_resource.permalink)
                           else
                             "/#{Spree::Config[:storefront_taxon_path]}/#{linked_resource.permalink}"
                           end
      when 'Spree::Product'
        return if linked_resource.nil?

        self.destination = if frontend_available?
                             Spree::Core::Engine.routes.url_helpers.product_path(linked_resource)
                           else
                             "/#{Spree::Config[:storefront_product_path]}/#{linked_resource.slug}"
                           end

      when 'Home Page'
        self.destination = '/'
      end
    end

    def reset_link_attributes
      if linked_resource_type_changed? || item_type == 'Container'
        self.linked_resource_id = nil
        self.destination = nil
        self.new_window = false

        self.linked_resource_type = 'URL' if item_type == 'Container'
      end
    end

    def frontend_available?
      Spree::Core::Engine.frontend_available?
    end

    def check_for_root
      if menu.try(:root).present? && parent_id.nil?
        errors.add(:root_conflict, Spree.t(:this_menu_already_has_a_root_item))
      end
    end

    def paremeterize_code
      return if code.blank?

      self.code = code.parameterize
    end
  end
end
