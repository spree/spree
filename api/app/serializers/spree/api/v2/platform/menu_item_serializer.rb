module Spree
  module Api
    module V2
      module Platform
        class MenuItemSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          has_one :image,
                  object_method_name: :icon,
                  id_method_name: :icon_id,
                  record_type: :image,
                  serializer: :image

          belongs_to :menu, serializer: :menu
          belongs_to :parent, record_type: :menu_item, serializer: :menu_item
          belongs_to :linked_resource, polymorphic: {
            Spree::Cms::Pages::StandardPage => :cms_page,
            Spree::Cms::Pages::FeaturePage => :cms_page,
            Spree::Cms::Pages::Homepage => :cms_page
          }

          has_many :children, record_type: :menu_item, serializer: :menu_item
        end
      end
    end
  end
end
