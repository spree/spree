module Spree
  module Variants
    class Create
      prepend Spree::ServiceModule::Base

      def call(product:, params:)
        ApplicationRecord.transaction do
          run :create_variant
          run :sync_prices
          run :sync_stock_items
        end
      end

      private

      def create_variant(product:, params:)
        params = params.to_h.with_indifferent_access
        prices_params = params.delete(:prices)
        stock_items_params = params.delete(:stock_items)
        option_type_name = params.delete(:option_type)
        option_value_name = params.delete(:option_value)
        total_on_hand = params.delete(:total_on_hand)

        variant = product.variants.build(params)

        if option_type_name.present? && option_value_name.present?
          assign_option_value(product, variant, option_type_name, option_value_name)
        end

        if variant.save
          # Simple single-location stock shortcut
          if total_on_hand.present? && stock_items_params.blank?
            variant.stock_items.first&.set_count_on_hand(total_on_hand.to_i)
          end

          success(variant: variant, prices_params: prices_params, stock_items_params: stock_items_params)
        else
          failure(variant, variant.errors)
        end
      end

      def sync_prices(variant:, prices_params:, stock_items_params:)
        upsert_prices(variant, prices_params) if prices_params.present?
        success(variant: variant, stock_items_params: stock_items_params)
      end

      def sync_stock_items(variant:, stock_items_params:)
        upsert_stock_items(variant, stock_items_params) if stock_items_params.present?
        success(variant: variant.reload)
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

      def upsert_stock_items(variant, stock_items_params)
        now = Time.current
        location_ids = []

        records = stock_items_params.map do |stock_data|
          stock_data = stock_data.to_h.with_indifferent_access
          stock_location = resolve_stock_location(stock_data[:stock_location_id])
          location_ids << stock_location.id
          {
            variant_id: variant.id,
            stock_location_id: stock_location.id,
            count_on_hand: stock_data[:count_on_hand].to_i,
            backorderable: stock_data[:backorderable] || false,
            created_at: now,
            updated_at: now
          }
        end

        # Soft-delete stock items for locations not in the payload
        Spree::StockItem.where(variant_id: variant.id)
                        .where.not(stock_location_id: location_ids)
                        .update_all(deleted_at: now)

        Spree::StockItem.upsert_all(
          records,
          unique_by: :index_spree_stock_items_unique_without_deleted_at,
          update_only: [:count_on_hand, :backorderable]
        )
      end

      def assign_option_value(product, variant, option_type_name, option_value_name)
        option_type = Spree::OptionType.where(name: option_type_name.to_s.parameterize).first_or_create! do |ot|
          ot.presentation = option_type_name
        end
        product.option_types << option_type unless product.option_types.include?(option_type)

        option_value = option_type.option_values.where(name: option_value_name.to_s.parameterize).first_or_create! do |ov|
          ov.presentation = option_value_name
        end
        variant.option_values = [option_value]
      end

      def resolve_stock_location(id)
        Spree::StockLocation.find_by_param!(id)
      end
    end
  end
end
