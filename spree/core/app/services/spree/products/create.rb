module Spree
  module Products
    class Create
      prepend Spree::ServiceModule::Base

      def call(store:, params:)
        ApplicationRecord.transaction do
          run :create_product
          run :create_variants
        end
      end

      private

      def create_product(store:, params:)
        params = params.to_h.with_indifferent_access
        variants_params = params.delete(:variants)
        product_params = params
        product_params[:store_ids] = [store.id] if product_params[:store_ids].blank?

        # Map tags array to tag_list
        product_params[:tag_list] = product_params.delete(:tags) if product_params.key?(:tags)

        # Extract IDs that after_initialize callbacks may overwrite
        tax_category_id = product_params.delete(:tax_category_id)
        shipping_category_id = product_params.delete(:shipping_category_id)

        product = Spree::Product.new(product_params)
        overrides = {}
        overrides[:tax_category_id] = tax_category_id if tax_category_id.present?
        overrides[:shipping_category_id] = shipping_category_id if shipping_category_id.present?
        product.assign_attributes(overrides) if overrides.any?

        if product.save
          success(product: product, store: store, variants_params: variants_params)
        else
          failure(product, product.errors)
        end
      end

      def create_variants(product:, store:, variants_params:)
        return success(product: product) if variants_params.blank?

        variants_params.each do |variant_data|
          variant_data = variant_data.to_h.with_indifferent_access
          prices_params = variant_data.delete(:prices)
          option_type_name = variant_data.delete(:option_type)
          option_value_name = variant_data.delete(:option_value)
          total_on_hand = variant_data.delete(:total_on_hand)

          variant = product.variants.build(variant_data)

          # Assign option value if provided
          if option_type_name.present? && option_value_name.present?
            option_type = Spree::OptionType.where(name: option_type_name.to_s.parameterize).first_or_create! do |ot|
              ot.presentation = option_type_name
            end
            product.option_types << option_type unless product.option_types.include?(option_type)

            option_value = option_type.option_values.where(name: option_value_name.to_s.parameterize).first_or_create! do |ov|
              ov.presentation = option_value_name
            end
            variant.option_values = [option_value]
          end

          unless variant.save
            return failure(variant, variant.errors)
          end

          # Set stock
          if total_on_hand.present?
            variant.stock_items.first&.set_count_on_hand(total_on_hand.to_i)
          end

          # Upsert prices
          upsert_prices(variant, prices_params) if prices_params.present?
        end

        success(product: product.reload)
      end

      def upsert_prices(variant, prices_params)
        now = Time.current
        currencies = []

        records = prices_params.map do |price_data|
          price_data = price_data.to_h.with_indifferent_access
          currencies << price_data[:currency]
          {
            variant_id: variant.id,
            currency: price_data[:currency],
            amount: price_data[:amount],
            compare_at_amount: price_data[:compare_at_amount],
            created_at: now,
            updated_at: now
          }
        end

        Spree::Price.where(variant_id: variant.id, price_list_id: nil)
                    .where.not(currency: currencies)
                    .update_all(deleted_at: now)

        Spree::Price.upsert_all(
          records,
          unique_by: :index_spree_prices_on_variant_id_and_currency,
          update_only: [:amount, :compare_at_amount]
        )
      end

    end
  end
end
