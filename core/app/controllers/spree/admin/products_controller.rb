module Spree
  module Admin
    class ProductsController < ResourceController
      helper 'spree/products'

      before_filter :check_json_authenticity, :only => :index
      before_filter :load_data, :except => :index
      create.before :create_before
      update.before :update_before

      def show
        redirect_to( :action => :edit )
      end

      def index
        respond_with(@collection) do |format|
          format.html
          format.json { render :json => json_data }
        end
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

        # Allow different formats of json data to suit different ajax calls
        def json_data
          json_format = params[:json_format] or 'default'
          case json_format
          when 'basic'
            collection.map {|p| {'id' => p.id, 'name' => p.name}}.to_json
          else
            collection.to_json(:include => {:variants => {:include => {:option_values => {:include => :option_type},
                                                          :images => {:only => [:id], :methods => :mini_url}}, :methods => :admin_label},
                                                          :images => {:only => [:id], :methods => :mini_url}, :master => {}})
          end
        end

        def load_data
          @taxons = Taxon.order(:name)
          @option_types = OptionType.order(:name)
          @tax_categories = TaxCategory.order(:name)
          @shipping_categories = ShippingCategory.order(:name)
        end

        def collection
          return @collection if @collection.present?

          unless request.xhr?
            params[:q] ||= {}
            params[:q][:deleted_at_null] ||= "1"

            params[:q][:s] ||= "name asc"

            @search = super.ransack(params[:q])
            @collection = @search.result.
              group_by_products_id.
              includes([:master, {:variants => [:images, :option_values]}]).
              page(params[:page]).
              per(Spree::Config[:admin_products_per_page])

            if params[:q][:s].include?("master_price")
              # By applying the group in the main query we get an undefined method gsub for Arel::Nodes::Descending
              # It seems to only work when the price is actually being sorted in the query
              # To be investigated later.
              @collection = @collection.group("spree_variants.price")
            end
          else
            includes = [{:variants => [:images,  {:option_values => :option_type}]}, {:master => :images}]

            @collection = super.where(["name #{LIKE} ?", "%#{params[:q]}%"])
            @collection = @collection.includes(includes).limit(params[:limit] || 10)

            tmp = super.where(["#{Variant.table_name}.sku #{LIKE} ?", "%#{params[:q]}%"])
            tmp = tmp.includes(:variants_including_master).limit(params[:limit] || 10)
            @collection.concat(tmp)
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
    end
  end
end
