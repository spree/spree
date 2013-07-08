module Spree
  module Admin
    class VariantsController < ResourceController
      belongs_to 'spree/product', :find_by => :permalink
      new_action.before :new_before

      # override the destory method to set deleted_at value
      # instead of actually deleting the product.
      def destroy
        @variant = Variant.find(params[:id])
        if @variant.destroy
          flash[:success] = Spree.t('notice_messages.variant_deleted')
        else
          flash[:success] = Spree.t('notice_messages.variant_not_deleted')
        end

        respond_with(@variant) do |format|
          format.html { redirect_to admin_product_variants_url(params[:product_id]) }
          format.js  { render_js_for_destroy }
        end
      end

      protected
        def new_before
          @object.attributes = @object.product.master.attributes.except('id', 'created_at', 'deleted_at',
                                                                        'sku', 'is_master')
          # Shallow Clone of the default price to populate the price field.
          @object.default_price = @object.product.master.default_price.clone
        end

        def collection
          @deleted = (params.key?(:deleted) && params[:deleted] == "on") ? "checked" : ""

          if @deleted.blank?
            @collection ||= super
          else
            @collection ||= Variant.where(:product_id => parent.id).deleted
          end
          @collection
        end
    end
  end
end
