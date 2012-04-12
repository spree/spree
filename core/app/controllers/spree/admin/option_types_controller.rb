module Spree
  module Admin
    class OptionTypesController < ResourceController
      before_filter :load_product, :only => [:select, :selected, :available, :remove]

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
        flash.notice = I18n.t('notice_messages.option_type_removed')
        redirect_to selected_admin_product_option_types_url(@product)
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
          @available_option_types = OptionType.all
          selected_option_types = []
          @product.options.each do |option|
            selected_option_types << option.option_type
          end
          @available_option_types.delete_if {|ot| selected_option_types.include? ot}
        end
    end
  end
end
