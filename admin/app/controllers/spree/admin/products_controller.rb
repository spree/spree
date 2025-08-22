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
        @products = scope.includes(master: :images, variants: :images).multi_search(query).limit(params[:limit] || 10)

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
          render :edit, status: :unprocessable_entity
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

      def bulk_modal
        if params[:kind] == 'set_status'
          @title = Spree.t('admin.bulk_ops.products.title.set_status', status: params[:status].titleize)
          @body = Spree.t("admin.bulk_ops.products.body.set_status.#{params[:status]}")
        else
          @title = Spree.t("admin.bulk_ops.products.title.#{params[:kind]}")
          @body = Spree.t("admin.bulk_ops.products.body.#{params[:kind]}")
        end
      end

      def bulk_status_update
        if bulk_collection.update_all(status: params[:status], updated_at: Time.current)
          product_ids = bulk_collection.ids

          if Spree::Webhooks::Subscriber.any?
            ::Spree::Products::QueueStatusChangedWebhook.call(
              ids: product_ids,
              event: Spree::Product::STATUS_TO_WEBHOOK_EVENT[params[:status]]
            )
          end

          invoke_callbacks(:bulk_status_update, :after)

          flash.now[:success] = Spree.t('admin.bulk_ops.products.status_updated', status: params[:status].titleize)
        else
          flash.now[:error] = Spree.t('something_went_wrong')
        end
      end

      def bulk_add_tags
        Spree::Tags::BulkAdd.call(tag_names: params[:tags], records: bulk_collection)
        Spree::Product.bulk_auto_match_taxons(current_store, bulk_collection.ids)

        handle_bulk_operation_response
      end

      def bulk_remove_tags
        Spree::Tags::BulkRemove.call(tag_names: params[:tags], records: bulk_collection)
        Spree::Product.bulk_auto_match_taxons(current_store, bulk_collection.ids)

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

            @product_options[option_type.id.to_s] = {
              name: option_type.presentation,
              position: index + 1,
              values: option_values.map { |ov| { value: ov.name, text: ov.presentation } }.uniq
            }

            @product_available_options[option_type.id.to_s] = option_type.option_values.map { |ov| { id: ov.name, name: ov.presentation } }.uniq
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
        @product.prices.includes(:variant).each do |price|
          @product_prices[price.variant.human_name] ||= {}
          @product_prices[price.variant.human_name][price.currency.downcase] = {
            id: price.id.to_s,
            amount: price.amount
          }
        end

        @product_variant_ids = {}

        @product.variants.includes(:option_values).each do |variant|
          @product_variant_ids[variant.human_name] = variant.id.to_s
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

      def collection
        return @collection if @collection.present?

        params[:q] ||= {}
        params[:q][:deleted_at_null] ||= '1'

        params[:q][:s] ||= 'name asc'
        params[:q][:status_eq] == 'archived' ? params[:q].delete(:status_not_eq) : params[:q][:status_not_eq] = 'archived'

        params[:q][:taxons_id_null] = '1' if params.dig(:q, :taxons_id_in)&.include?(' ')

        assign_extra_collection_params if respond_to?(:assign_extra_collection_params)

        @collection = super

        # Don't delete params[:q][:deleted_at_null] here because it is used in view to check the
        # checkbox for 'q[deleted_at_null]'. This also messed with pagination when deleted_at_null is checked.
        @collection = @collection.with_deleted if params[:q][:deleted_at_null] == '0'

        # The out_of_stock scope groups products - we also need to group it by name coming from product translations
        # That's because we sort products by name
        @collection = @collection.group(:name) if params.dig(:q, :out_of_stock_items) == '1'

        # @search needs to be defined as this is passed to search_form_for
        # Temporarily remove params[:q][:deleted_at_null] from params[:q] to ransack products.
        # This is to include all products and not just deleted products.
        @search = @collection.ransack(params[:q].except(:deleted_at_null))
        @collection = @search.result(distinct: true).
                      for_ordering_with_translations(model_class, :name).
                      includes(product_includes).
                      page(params[:page]).
                      per(params[:per_page] || Spree::Admin::RuntimeConfig.admin_products_per_page)

        @collection
      end

      def clone_object_url(resource)
        clone_admin_product_url resource
      end

      private

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
          @product.master.stock_items.build(stock_location_id: id, count_on_hand: 0) unless @product.master.stock_items.find { |stock_item| stock_item.stock_location_id == id }
        end
      end

      def master_stock_items_locations_opts
        {}
      end

      def build_product_properties
        Spree::Property.all.each do |property|
          @product.product_properties.build(property: property) unless @product.product_properties.find { |product_property| product_property.property_id == property.id }
        end
      end

      def assign_master_images
        return unless @product.master.persisted?

        uploaded_assets = session_uploaded_assets('Spree::Variant')

        return if uploaded_assets.empty?

        uploaded_assets.update_all(viewable_id: @product.master.id, viewable_type: 'Spree::Variant', updated_at: Time.current)
        clear_session_for_uploaded_assets('Spree::Variant')
      end

      def product_includes
        {
          tax_category: [],
          stock_items: [:stock_location],
          variants_including_master: [],
          shipping_category: [],
          master: [:prices, :images, :stock_items, :stock_locations],
          variants: [:prices, :images, :stock_items, :stock_locations],
          variant_images: [],
        }
      end

      def check_slug_availability
        new_slug = permitted_resource_params[:slug]
        permitted_resource_params[:slug] = @product.ensure_slug_is_unique(new_slug)
      end

      def permitted_resource_params
        @permitted_resource_params ||= begin
          if cannot?(:activate, @product) && @new_status&.to_sym == :active
            params.require(:product).permit(permitted_product_attributes).except(:status, :make_active_at)
          else
            params.require(:product).permit(permitted_product_attributes)
          end
        end
      end
    end
  end
end
