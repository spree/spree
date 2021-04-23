module Spree
  class MenuItem < Spree::Base
    belongs_to :menu
    belongs_to :linked_resource, polymorphic: true

    acts_as_nested_set dependent: :destroy

    before_save :reset_link_attributes
    before_save :check_for_image
    before_save :build_path

    has_one_attached :image_asset

    ITEM_TYPE = %w[Link Promotion Container]

    LINKED_RESOURCE_TYPE = ['URL']
    STATIC_RESOURCE_TYPE = ['Home Page']
    DYNAMIC_RESOURCE_TYPE = ['Spree::Product', 'Spree::Taxon']

    LINKED_RESOURCE_TYPE.unshift(*STATIC_RESOURCE_TYPE)
    LINKED_RESOURCE_TYPE.push(*DYNAMIC_RESOURCE_TYPE)

    validates :name, presence: true
    validates :menu_id, presence: true, numericality: { only_integer: true }
    validates :item_type, inclusion: { in: ITEM_TYPE }
    validates :linked_resource_type, inclusion: { in: LINKED_RESOURCE_TYPE }

    def self.refresh_paths(resorce)
      where(linked_resource_type: resorce.class.name, linked_resource_id: resorce.id).each(&:save!)
    end

    private

    def build_path
      if DYNAMIC_RESOURCE_TYPE.include? linked_resource_type
        return if linked_resource.nil?

        case linked_resource_type
        when 'Spree::Taxon'
          self.destination = if frontend_available?
                               Spree::Core::Engine.routes.url_helpers.nested_taxons_path(linked_resource.permalink)
                             else
                               "/#{Spree::Config[:api_taxon_path]}/#{linked_resource.permalink}"
                             end
        when 'Spree::Product'
          self.destination = if frontend_available?
                               Spree::Core::Engine.routes.url_helpers.product_path(linked_resource)
                             else
                               "/#{Spree::Config[:api_product_path]}/#{linked_resource.slug}"
                             end

        end
      else
        case linked_resource_type
        when 'Home Page'
          self.destination = '/'
        end
      end
    end

    def check_for_image
      self.has_attached_image = if image_asset.attached?
                                  true
                                else
                                  false
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
  end
end
