module Spree
  module Api
    module V2
      module Storefront
        class VariantsController < ::Spree::Api::V2::ResourceController
          private

          def model_class
            Spree::Variant
          end

          def scope
            product_scope = Spree::Product.for_store(current_store)
            product_scope = product_scope.accessible_by(current_ability, :show)
            product_scope = product_scope.i18n if model_class.include?(TranslatableResource)

            product = product_scope.friendly.find(params[:id])
            product.variants_including_master
          end

          def collection_finder
            Spree.api.storefront_variant_finder
          end

          def collection_serializer
            Spree.api.storefront_variant_serializer
          end

          def scope_includes
            variant_includes = {
              prices: [],
              option_values: :option_type,
            }
            variant_includes[:images] = [] if params[:include]&.match(/images/)
            variant_includes
          end
        end
      end
    end
  end
end
