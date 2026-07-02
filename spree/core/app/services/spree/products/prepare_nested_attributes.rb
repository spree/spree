module Spree
  module Products
    # Prepares nested attributes for product updates, handling multi-store scenarios
    # and permissions.
    #
    # This service ensures that when editing a product in one store, taxon associations
    # from other stores are preserved. This prevents accidental data loss when a store
    # admin updates product categories in their store without affecting other stores.
    #
    # @example
    #   service = Spree::Products::PrepareNestedAttributes.new(
    #     product,
    #     current_store,
    #     params,
    #     current_ability
    #   )
    #   prepared_params = service.call
    #
    class PrepareNestedAttributes
      attr_reader :variants_to_discontinue

      def initialize(product, store, params, ability)
        @product = product
        @store = store
        @params = params
        @ability = ability
        @variants_to_discontinue = []
      end

      def call
        if params[:variants_attributes]
          params[:variants_attributes].each do |key, variant_params|
            existing_variant = variant_params[:id].presence && @product.variants.find_by(id: variant_params[:id])
            variants_to_remove.delete(variant_params[:id]) if variant_params[:id].present?

            variant_params.delete(:price) # remove legacy price param

            if can_update_prices?
              backfill_price_ids!(variant_params, existing_variant)

              variant_params[:prices_attributes]&.each do |price_key, price_params|
                variant_params[:prices_attributes][price_key]['_destroy'] = '1' if price_params[:amount].blank?
              end
            else
              variant_params.delete(:prices_attributes)
            end

            variant_params[:option_value_variants_attributes] = update_option_value_variants(variant_params.delete(:options), existing_variant)

            variant_params.delete(:stock_items_attributes) unless can_update_stock_items?

            params[:variants_attributes].delete(key) if variant_params.blank?
          end
          params[:variants_attributes] = params[:variants_attributes].merge(removed_variants_attributes)

          params[:product_option_types_attributes] = product_option_types_params.merge(removed_product_option_types_attributes)
        end

        params.delete(:legacy_product_publications_attributes) unless can?(:manage, Spree::ProductPublication)

        # ensure the product is owned by a store
        params[:store_id] = store.id if params[:store_id].blank? && product.store_id.blank?

        # Add empty list for option_type_ids and mark variants as removed if there are no variants and options
        if params[:variants_attributes].blank? && variants_to_remove.any? && !params.key?(:option_type_ids)
          params[:option_type_ids] = []
          params[:variants_attributes] = {}

          populate_variants_to_discontinue
          variant_ids_to_destroy.each_with_index do |variant_id, index|
            params[:variants_attributes][index.to_s] = { id: variant_id, _destroy: '1' }
          end

          params[:variants_attributes].permit!
        end

        params
      end

      private

      attr_reader :product, :store, :params, :ability

      delegate :can?, :cannot?, to: :ability

      # Backfill IDs for prices_attributes entries that reference existing prices
      # so that ActiveRecord updates them instead of inserting duplicates
      def backfill_price_ids!(variant_params, existing_variant)
        return unless existing_variant && variant_params[:prices_attributes]

        variant_params[:prices_attributes].each do |_key, price_params|
          next if price_params[:id].present?
          next if price_params[:currency].blank?

          existing_price = existing_variant.prices.base_prices.find_by(currency: price_params[:currency])
          price_params[:id] = existing_price.id if existing_price
        end
      end

      def product_option_types_params
        @product_option_types_params ||= {}
      end

      def product_option_types_to_remove
        @product_option_types_to_remove ||= product.product_option_type_ids
      end

      def variants_to_remove
        @variants_to_remove ||= product.variant_ids.map(&:to_s)
      end

      def can_update_prices?
        @can_update_prices ||= product.new_record? || can?(:manage, Spree::Price.new(variant_id: product.default_variant.id))
      end

      def can_manage_option_types?
        @can_manage_option_types ||= product.new_record? || can?(:manage_option_types, product)
      end

      def can_update_stock_items?
        @can_update_stock_items ||= product.new_record? || can?(:manage, Spree::StockItem.new(variant_id: product.default_variant.id))
      end

      def can_remove_variants?
        @can_remove_variants ||= product.persisted? && can?(:destroy, product.default_variant)
      end

      def removed_variants_attributes
        return {} unless can_remove_variants?

        populate_variants_to_discontinue

        attributes = {}
        last_index = params[:variants_attributes].keys.map(&:to_i).max
        variant_ids_to_destroy.each_with_index do |variant_id, index|
          attributes[(last_index + 1 + index).to_s] = { id: variant_id, _destroy: '1' }
        end

        attributes
      end

      def populate_variants_to_discontinue
        ids = variants_to_remove.select { |vid| variant_ids_with_completed_orders.include?(vid) }
        @variants_to_discontinue = product.variants.where(id: ids).to_a if ids.any?
      end

      def variant_ids_to_destroy
        variants_to_remove - variant_ids_with_completed_orders
      end

      def variant_ids_with_completed_orders
        @variant_ids_with_completed_orders ||=
          product.variants
                 .joins(:orders)
                 .merge(Spree::Order.complete)
                 .reorder(nil)
                 .distinct
                 .pluck(:id)
                 .map(&:to_s)
      end

      def removed_product_option_types_attributes
        return {} unless can_manage_option_types?

        attributes = {}
        last_index = product_option_types_params.keys.map(&:to_i).max
        product_option_types_to_remove.each_with_index do |product_option_type_id, index|
          attributes[(last_index + index + 1).to_s] = { id: product_option_type_id, _destroy: '1' }
        end

        attributes
      end

      def update_option_value_variants(option_value_params, existing_variant)
        return {} unless option_value_params.present?
        return {} unless can_manage_option_types?

        option_value_variant_params = {}

        option_value_params.each_with_index do |opt, index|
          option_type = Spree::OptionType.find_by_param(opt[:id]) if opt.fetch(:id)
          option_type ||= Spree::OptionType.where(name: opt[:name].parameterize).first_or_initialize do |o|
            o.name = o.presentation = opt[:name]
            o.position = opt[:position]
            o.save!
          end

          option_value_identificator = if opt[:option_value_name].present?
                                         opt[:option_value_name]
                                       else
                                         opt[:option_value_presentation]
                                       end.parameterize.strip

          option_value = option_type.option_values.where(name: option_value_identificator).first_or_initialize do |o|
            o.presentation = opt[:option_value_presentation]
            o.save!
          end

          existing_option_value_variant = existing_variant&.option_value_variants&.find { |ovv| ovv.option_value_id == option_value.id }

          option_value_variant_params[index.to_s] = { id: existing_option_value_variant&.id, option_value_id: option_value.id }.compact_blank

          next if product_option_types_params.find { |_i, v| v[:option_type_id] == option_type.id }

          existing_product_option_type = @product.product_option_types.find { |pot| pot.option_type_id == option_type.id }

          if existing_product_option_type
            product_option_types_to_remove.delete(existing_product_option_type.id)
            product_option_types_params[opt[:position]] = {
              id: existing_product_option_type.id,
              position: opt[:position],
              option_type_id: option_type.id
            }
          else
            product_option_types_params[opt[:position]] = {
              option_type_id: option_type.id,
              position: opt[:position]
            }
          end
        end

        option_value_variant_params
      end
    end
  end
end
