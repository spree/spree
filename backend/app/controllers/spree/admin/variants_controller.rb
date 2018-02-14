module Spree
  module Admin
    class VariantsController < ResourceController
      belongs_to 'spree/product', find_by: :slug
      new_action.before :new_before
      before_action :redirect_on_empty_option_values, only: [:new]
      before_action :load_data, only: [:new, :create, :edit, :update]

      # override the destroy method to set deleted_at value
      # instead of actually deleting the product.
      def destroy
        @variant = Variant.find(params[:id])
        if @variant.destroy
          flash[:success] = Spree.t('notice_messages.variant_deleted')
        else
          flash[:error] = Spree.t('notice_messages.variant_not_deleted', error: @variant.errors.full_messages.to_sentence)
        end

        respond_with(@variant) do |format|
          format.html { redirect_to admin_product_variants_url(params[:product_id]) }
          format.js { render_js_for_destroy }
        end
      end

      protected

      def new_before
        master = @object.product.master
        @object.attributes = master.attributes.except(
          'id', 'created_at', 'deleted_at', 'sku', 'is_master'
        )

        # Shallow Clone of the default price to populate the price field.
        @object.default_price = master.default_price.clone if master.default_price.present?
      end

      def parent
        @product = Product.with_deleted.friendly.find(params[:product_id])
      end

      def collection
        @deleted = params.key?(:deleted) && params[:deleted] == 'on' ? 'checked' : ''

        @collection ||=
          if @deleted.blank?
            super.includes(:default_price, option_values: :option_type)
          else
            Variant.only_deleted.where(product_id: parent.id)
          end
        @collection
      end

      private

      def load_data
        @tax_categories = TaxCategory.order(:name)
      end

      def redirect_on_empty_option_values
        redirect_to admin_product_variants_url(params[:product_id]) if @product.empty_option_values?
      end
    end
  end
end
