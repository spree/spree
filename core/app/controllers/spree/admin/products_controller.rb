module Spree
  module Admin
    class ProductsController < ResourceController
      helper 'spree/products'

#      before_filter :check_json_authenticity, :only => :index
      before_filter :load_data, :except => :index
      create.before :create_before
      update.before :update_before

      def show
        redirect_to( :action => :edit )
      end

      def index
        respond_with(@collection)
      end

      def destroy
        @product = Product.where(:permalink => params[:id]).first!
        @product.delete

        flash.notice = I18n.t('notice_messages.product_deleted')

        respond_with(@product) do |format|
          format.html { redirect_to collection_url }
          format.js  { render_js_for_destroy }
        end
      end

      def clone
        @new = @product.duplicate

        if @new.save
          flash.notice = I18n.t('notice_messages.product_cloned')
        else
          flash.notice = I18n.t('notice_messages.product_not_cloned')
        end

        respond_with(@new) { |format| format.html { redirect_to edit_admin_product_url(@new) } }
      end

      protected

        def find_resource
          Product.find_by_permalink!(params[:id])
        end

        def location_after_save
          edit_admin_product_url(@product)
        end

        def load_data
          @taxons = Taxon.order(:name)
          @option_types = OptionType.order(:name)
          @tax_categories = TaxCategory.order(:name)
          @shipping_categories = ShippingCategory.order(:name)
        end

        def collection
          return @collection if @collection.present?
          params[:q] ||= {}
          params[:q][:deleted_at_null] ||= "1"

          params[:q][:s] ||= "name asc"

          @search = super.ransack(params[:q])
          @collection = @search.result.
            group_by_products_id.
            includes(product_includes).
            page(params[:page]).
            per(Spree::Config[:admin_products_per_page])

          if params[:q][:s].include?("master_price")
            # PostgreSQL compatibility
            @collection = @collection.group("spree_variants.price")
          end
          @collection
        end

        def create_before
          return if params[:product][:prototype_id].blank?
          @prototype = Spree::Prototype.find(params[:product][:prototype_id])
        end

        def update_before
          # note: we only reset the product properties if we're receiving a post from the form on that tab
          return unless params[:clear_product_properties]
          params[:product] ||= {}
        end

        def product_includes
         [{:variants => [:images, {:option_values => :option_type}]}, {:master => :images}]
        end

    end
  end
end
