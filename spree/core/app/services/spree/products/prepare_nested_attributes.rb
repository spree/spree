module Spree
  module Products
    # Prepares nested attributes for product updates, handling multi-store scenarios
    # and permissions.
    #
    # This service ensures that when editing a product in one store, taxon associations
    # from other stores are preserved. This prevents accidental data loss when a store
    # admin updates product categories in their store without affecting other stores.
    #
    # Variant removal is opt-in: only variants explicitly listed in the
    # `removed_variant_ids` param are marked for destruction (or collected for
    # discontinuation when they have completed orders). Variants merely absent from
    # `variants_attributes` are left untouched, so a partially rendered or broken
    # form can never silently mass-delete variants.
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
        extract_removed_variant_ids

        if params[:variants_attributes]
          params[:variants_attributes].each do |key, variant_params|
            existing_variant = variant_params[:id].presence && @product.variants.find_by(id: variant_params[:id])
            # a re-submitted variant always wins over a removal request
            variants_to_remove.delete(variant_params[:id].to_s) if variant_params[:id].present?

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

        # The variants matrix was emptied: no variant rows re-submitted, removals sent instead.
        # Option types are detached only when the removal list covers every variant, so a
        # partial (possibly broken) submission never turns the product into a simple one.
        # Variants kept alive by discontinuation still count as removed from the matrix,
        # so the detachment can't hinge on any of them yielding a `_destroy` row.
        if params[:variants_attributes].blank? && variants_to_remove.any? && can_remove_variants?
          attributes = removed_variants_attributes

          params[:option_type_ids] = [] if removing_all_variants? && !params.key?(:option_type_ids)

          if attributes.any?
            params[:variants_attributes] = attributes
            params[:variants_attributes].permit!
          end
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

      # Pulls `removed_variant_ids` out of the params so it never reaches Product#update.
      # Must run before any `variants_to_remove` access.
      def extract_removed_variant_ids
        @removed_variant_ids = Array(params.delete(:removed_variant_ids)).map(&:to_s)
      end

      # Only variants the client explicitly asked to remove, and only ones that
      # actually belong to this product.
      def variants_to_remove
        @variants_to_remove ||= (@removed_variant_ids || []).uniq & all_variant_ids
      end

      def all_variant_ids
        @all_variant_ids ||= product.variant_ids.map(&:to_s)
      end

      def removing_all_variants?
        (all_variant_ids - variants_to_remove).empty?
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
        last_index = params[:variants_attributes].presence&.keys&.map(&:to_i)&.max || -1
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
