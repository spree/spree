module Spree
  module Admin
    class ImagesController < ResourceController
      before_filter :load_data

      create.before :set_viewable
      update.before :set_viewable

      private

        def location_after_destroy
          admin_product_images_url(@product)
        end

        def location_after_save
          admin_product_images_url(@product)
        end

        def load_data
          @product = Product.find_by_permalink(params[:product_id])
          @variants = @product.variants.collect do |variant|
            [variant.options_text, variant.id]
          end
          @variants.insert(0, [Spree.t(:all), @product.master.id])
        end

        def set_viewable
          @image.viewable_type = 'Spree::Variant'
          @image.viewable_id = params[:image][:viewable_id]
        end

    end
  end
end
