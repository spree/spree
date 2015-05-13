module Spree
  module Admin
    class OptionTypesController < ResourceController
      before_action :setup_new_option_value, only: :edit

      def update_values_positions
        ActiveRecord::Base.transaction do
          params[:positions].each do |id, index|
            Spree::OptionValue.where(id: id).update_all(position: index)
          end
        end

        respond_to do |format|
          format.html { redirect_to admin_product_variants_url(params[:product_id]) }
          format.js { render text: 'Ok' }
        end
      end

      protected

        def location_after_save
          if @option_type.created_at == @option_type.updated_at
            edit_admin_option_type_url(@option_type)
          else
            admin_option_types_url
          end
        end


      private
        def load_product
          @product = Product.friendly.find(params[:product_id])
        end

        def setup_new_option_value
          @option_type.option_values.build if @option_type.option_values.empty?
        end

        def set_available_option_types
          @available_option_types = if @product.option_type_ids.any?
            OptionType.where('id NOT IN (?)', @product.option_type_ids)
          else
            OptionType.all
          end
        end
    end
  end
end
