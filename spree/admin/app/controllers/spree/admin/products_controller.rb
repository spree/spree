module Spree
  module Admin
    class ProductsController < ResourceController
      include Spree::Admin::StockLocationsHelper
      include Spree::Admin::BulkOperationsConcern
      include Spree::Admin::AssetsHelper
      include Spree::Admin::ProductsBreadcrumbConcern

      helper 'spree/admin/products'
      helper 'spree/admin/taxons'

      before_action :load_data, except: :index
      before_action :load_variants_data, only: %i[edit update]
      before_action :set_product_defaults, only: :new

      before_action :prepare_product_params, only: [:create, :update]
      before_action :strip_stock_items_param, only: [:create, :update]
      before_action :check_slug_availability, only: [:create, :update]

      new_action.before :build_master_prices
      new_action.before :build_master_stock_items
      new_action.before :build_product_properties
      edit_action.before :build_master_prices
      edit_action.before :build_master_stock_items
      edit_action.before :build_product_properties
      create.after :assign_master_images
      update.before :skip_updating_status
      update.before :update_status
      update.before :remove_empty_params
      helper_method :clone_object_url

      # https://blog.corsego.com/hotwire-turbo-streams-autocomplete-search
      def search
        query = params[:q]&.strip

        head :ok and return if query.blank? || query.length < 3

        scope = current_store.products.not_archived.accessible_by(current_ability, :index)
        scope = scope.where.not(id: params[:omit_ids].split(',')) if params[:omit_ids].present?
        @products = scope.includes(:thumbnail).multi_search(query).limit(params[:limit] || 10)

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(
                'products_search_results',
                partial: 'spree/admin/products/search_results',
                locals: { products: @products }
              )
            ]
          end
        end
      end

      def show
        redirect_to action: :edit
      end

      def update
        invoke_callbacks(:update, :before)

        if @product.update(permitted_resource_params)
          set_current_store
          invoke_callbacks(:update, :after)
          flash[:success] = flash_message_for(@product, :successfully_updated)
          redirect_to location_after_save
        else
          # Stops people submitting blank slugs, causing errors when they try to
          # update the product again
          @product.slug = @product.slug_was if @product.slug.blank?
          invoke_callbacks(:update, :fails)
          render :edit, status: :unprocessable_content
        end
      end

      def clone
        clone_result = @product.duplicate

        if clone_result.success?
          flash[:success] = Spree.t('notice_messages.product_cloned')
          redirect_to spree.edit_admin_product_path(clone_result.value)
        else
          flash[:error] = Spree.t('notice_messages.product_not_cloned', error: clone_result.error.value)
          redirect_to spree.edit_admin_product_path(@product)
        end
      end

      def bulk_status_update
        bulk_collection.update_all(status: params[:status], updated_at: Time.current)
        invoke_callbacks(:bulk_status_update, :after)

        handle_bulk_operation_response
      end

      def bulk_remove_from_taxons
        taxons = current_store.taxons.accessible_by(current_ability, :manage).where(id: params[:taxon_ids])
        Spree::Taxons::RemoveProducts.call(taxons: taxons, products: bulk_collection)
        Spree::Product.bulk_auto_match_taxons(current_store, bulk_collection.ids)

        handle_bulk_operation_response
      end

      def bulk_add_to_taxons
        taxons = current_store.taxons.accessible_by(current_ability, :manage).where(id: params[:taxon_ids])
        Spree::Taxons::AddProducts.call(taxons: taxons, products: bulk_collection)
        Spree::Product.bulk_auto_match_taxons(current_store, bulk_collection.ids)

        handle_bulk_operation_response
      end

      def select_options
        render json: current_store.products.not_archived.accessible_by(current_ability, :index).to_tom_select_json
      end

      protected

      def find_resource
        current_store.products.accessible_by(current_ability, :manage).friendly.find(params[:id])
      end

      def load_data
        @taxons = Taxon.order(:name)
        @option_types = OptionType.order(:name)
        @tax_categories = TaxCategory.order(:name)
        @shipping_categories = ShippingCategory.order(:name)
      end

      def load_variants_data
        return unless @product.has_variants?

        @product_options = {}
        @product_available_options = {}

        @product.
          option_values.
          joins(option_type: :product_option_types).
          includes(option_type: :option_values).
          merge(@product.product_option_types).
          reorder("#{Spree::ProductOptionType.table_name}.position", "#{Spree::Variant.table_name}.position").
          uniq.group_by(&:option_type).each_with_index do |option, index|
            option_type, option_values = option

            @product_options[option_type.prefixed_id] = {
              name: option_type.presentation,
              position: index + 1,
              values: option_values.map { |ov| { value: ov.name, text: ov.presentation } }.uniq
            }

            @product_available_options[option_type.prefixed_id] = option_type.option_values.map { |ov| { id: ov.name, name: ov.presentation } }.uniq
          end

        @product_stock = {}
        @product.stock_items.includes(:variant).each do |stock_item|
          @product_stock[stock_item.variant.human_name] ||= {}
          @product_stock[stock_item.variant.human_name][stock_item.stock_location_id.to_s] = {
            count_on_hand: stock_item.count_on_hand,
            backorderable: stock_item.backorderable,
            id: stock_item.id.to_s
          }
        end

        @product_prices = {}
        @product.prices.base_prices.includes(:variant).each do |price|
          @product_prices[price.variant.human_name] ||= {}
          @product_prices[price.variant.human_name][price.currency.downcase] = {
            id: price.id.to_s,
            amount: price.amount
          }
        end

        @product_variant_ids = {}
        @product_variant_prefix_ids = {}

        @product.variants.includes(:option_values).each do |variant|
          @product_variant_ids[variant.human_name] = variant.id.to_s
          @product_variant_prefix_ids[variant.human_name] = variant.to_param
        end
      end

      def set_product_defaults
        @product.shipping_category ||= @shipping_categories&.first
      end

      def skip_updating_status
        @new_status = params[:product].delete(:status)
      end

      def update_status
        return if @new_status == @product.status
        return if cannot?(:activate, @product) && @new_status&.to_sym == :active

        event_to_fire = @product.status_transitions.find { |transition| transition.from == @product.status && transition.to == @new_status }&.event
        @product.status_event = event_to_fire if event_to_fire
      end

      def remove_empty_params
        reject_empty_params(:tag_list) if can?(:manage_tags, @product)
        reject_empty_params(:taxon_ids)
        reject_empty_params(:label_list) if can?(:manage_labels, @product)
      end

      def reject_empty_params(key)
        params[:product][key] = params[:product][key].present? ? params[:product][key].reject(&:empty?) : []
      end

      def prepare_product_params
        params_service = Spree::Products::PrepareNestedAttributes.new(@product, current_store, permitted_resource_params, current_ability)
        params[:product] = params_service.call
      end

      # These includes are not picked automatically by ar_lazy_preload gem so we need to specify them manually.
      def collection_default_sort
        'name asc'
      end

      def collection_includes
        {
          thumbnail: [attachment_attachment: :blob],
          stock_items: [],
          master: [:prices, :stock_items],
          variants: [:prices, :stock_items]
        }
      end

      def clone_object_url(resource)
        clone_admin_product_url resource
      end

      private

      def after_bulk_tags_change
        Spree::Product.bulk_auto_match_taxons(current_store, bulk_collection.ids)
      end

      def variant_stock_includes
        [:images, { stock_items: :stock_location, option_values: :option_type }]
      end

      def strip_stock_items_param
        if params.dig(:product, :track_inventory) == '0'
          if params.dig(:product, :master_attributes, :stock_items_attributes).present?
            params[:product][:master_attributes][:stock_items_attributes] = {}
          end
          if params.dig(:product, :variants_attributes)
            params[:product][:variants_attributes].each do |_key, variant|
              variant[:stock_items_attributes] = {}
            end
          end
        end
      end

      def build_master_prices
        return if @product.has_variants?

        current_store.supported_currencies_list.each do |currency|
          @product.master.prices.build(currency: currency) unless @product.master.prices.find { |price| price.currency == currency }
        end
      end

      def build_master_stock_items
        return if @product.has_variants?

        available_stock_locations_list(master_stock_items_locations_opts).each do |_name, id|
          @product.master.stock_items.build(stock_location_id: id, count_on_hand: 0) unless @product.master.stock_items.find do |stock_item|
            stock_item.stock_location_id == id
          end
        end
      end

      def master_stock_items_locations_opts
        {}
      end

      def build_product_properties
        return unless Spree::Config[:product_properties_enabled]

        Spree::Property.all.each do |property|
          @product.product_properties.build(property: property) unless @product.product_properties.find do |product_property|
            product_property.property_id == property.id
          end
        end
      end

      def assign_master_images
        return unless @product.master.persisted?

        uploaded_assets = session_uploaded_assets('Spree::Variant')

        return if uploaded_assets.empty?

        uploaded_assets.update_all(viewable_id: @product.master.id, viewable_type: 'Spree::Variant', updated_at: Time.current)
        clear_session_for_uploaded_assets('Spree::Variant')
      end

      def check_slug_availability
        new_slug = permitted_resource_params[:slug]
        permitted_resource_params[:slug] = @product.ensure_slug_is_unique(new_slug)
      end

      def permitted_resource_params
        @permitted_resource_params ||= if cannot?(:activate, @product) && @new_status&.to_sym == :active
                                         params.require(:product).permit(permitted_product_attributes).except(:status, :make_active_at)
                                       else
                                         params.require(:product).permit(permitted_product_attributes)
                                       end
      end
    end
  end
end
