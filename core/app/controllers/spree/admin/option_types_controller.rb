module Spree
  module Admin
    class OptionTypesController < ResourceController
      before_filter :load_product, :only => [:select, :selected, :available, :remove]
      before_filter :setup_new_option_value, :only => [:edit]

      def available
        set_available_option_types
        render :layout => false
      end

      def selected
        @option_types = @product.option_types
      end

      def remove
        @product.option_types.delete(@option_type)
        @product.save
        @option_types = @product.option_types

        respond_with(@option_types) do |format|
          flash.notice = I18n.t('notice_messages.option_type_removed')

          format.js { render_js_for_destroy }
          format.html { redirect_to selected_admin_product_option_types_url(@product) }
        end
      end

      def update_positions
        params[:positions].each do |id, index|
          OptionType.where(:id => id).update_all(:position => index)
        end
    
        respond_to do |format|
          format.html { redirect_to admin_product_variants_url(params[:product_id]) }
          format.js  { render :text => 'Ok' }
        end
      end

      # AJAX method for selecting an existing option type and associating with the current product
      def select
        @product.option_types << OptionType.find(params[:id])
        @product.reload
        @option_types = @product.option_types
        set_available_option_types
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
          @product = Product.find_by_param!(params[:product_id])
        end
  
        def set_available_option_types     
          @available_option_types = if @product.option_type_ids.any?
            OptionType.where('id NOT IN (?)', @product.option_type_ids)
          else
            OptionType.all
          end
        end

        def setup_new_option_value
          @option_type.option_values.build if @option_type.option_values.blank?
        end
    end
  end
end
