module Spree
  module Api
    module V2
      module ProductListIncludes
        def product_list_includes
          @product_list_includes ||= {
            taggings: [:tag],
            variants: [],
            master: [:prices]
          }

          @product_list_includes[:variant_images] = [] if params[:include]&.match('images')
          @product_list_includes[:option_types] = [] if params[:include]&.match('option_types')
          @product_list_includes[:product_properties] = [:property] if params[:include]&.match('product_properties')
          @product_list_includes[:master] = variant_includes if params[:include]&.match(/master|default_variant/)
          @product_list_includes[:variants] = variant_includes if params[:include]&.match(/variants|default_variant/)
          @product_list_includes[:taxons] = [:taxonomy, :icon, :store, :rich_text_translations, image_attachment: :blob] if params[:include]&.match('taxons')
          @product_list_includes
        end

        def variant_includes
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
