module Spree
  module Api
    module V2
      module Storefront
        class MenusController < ::Spree::Api::V2::ResourceController
          private

          def resource_serializer
            Spree::Api::Dependencies.storefront_menu_serializer.constantize
          end

          def collection_serializer
            Spree::Api::Dependencies.storefront_menu_serializer.constantize
          end

          def collection_finder
            Spree::Api::Dependencies.storefront_menu_finder.constantize
          end

          def model_class
            Spree::Menu
          end

          def scope
            super.by_locale(I18n.locale)
          end

          def scope_includes
            { menu_items: [:children, :parent, :icon] }
          end
        end
      end
    end
  end
end
