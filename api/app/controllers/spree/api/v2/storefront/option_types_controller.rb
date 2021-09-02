module Spree
  module Api
    module V2
      module Storefront
        class OptionTypesController < ::Spree::Api::V2::ResourceController
          private

          def resource_serializer
            Spree::Api::Dependencies.storefront_option_type_serializer.constantize
          end

          def collection_serializer
            Spree::Api::Dependencies.storefront_option_type_serializer.constantize
          end

          def collection_finder
            Spree::Api::Dependencies.storefront_option_type_finder.constantize
          end

          def model_class
            Spree::OptionType
          end

          def scope_includes
            [:option_values]
          end
        end
      end
    end
  end
end
