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

    def self.refresh_paths(resorce, old_value)
      where(linked_resource_type: resorce.class.name).where('path LIKE ?', "%/#{old_value}%").each(&:save!)
    end

    private

    def build_path
      if DYNAMIC_RESOURCE_TYPE.include? linked_resource_type
        return if linked_resource_id.nil?

        case linked_resource_type
        when 'Spree::Taxon'
          self.path = if frontend_available?
                        Spree::Core::Engine.routes.url_helpers.nested_taxons_path(linked_resource.permalink)
                      else
                        "/#{Spree::Config[:api_taxon_path]}/#{linked_resource.permalink}"
                      end
        when 'Spree::Product'
          self.path = if frontend_available?
                        Spree::Core::Engine.routes.url_helpers.product_path(linked_resource)
                      else
                        "/#{Spree::Config[:api_product_path]}/#{linked_resource.slug}"
                      end
        end
      end
    end

    def check_for_image
      self.uses_attached_image = if image_asset.attached?
                                   true
                                 else
                                   false
                                 end
    end

    def reset_link_attributes
      if linked_resource_type_changed?
        self.linked_resource_id = nil
        self.url = nil
        self.path = nil
        self.new_window = false
      end
    end

    def frontend_available?
      Spree::Core::Engine.frontend_available?
    end
  end
end
