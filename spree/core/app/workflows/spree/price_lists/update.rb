module Spree
  module PriceLists
    # Updates a price list and applies the price overrides that ride with it.
    # Product membership is not part of this payload — it lives on the
    # uniform nested products surface, the same protocol categories,
    # collections and catalogs use.
    class Update < Spree::Workflow
      hooks :validate, :after_update

      # @param price_list [Spree::PriceList]
      # @param attributes [Hash] may carry `prices`
      # @return [Spree::ServiceModule::Result] value is the price list
      def perform(price_list:, attributes: {})
        super

        step :assign_attributes
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_price_list
          step :apply_prices
          run_hooks :after_update
        end

        success(price_list)
      end

      private

      # The price payload is held back rather than assigned, so the record
      # saves as a plain row and the rows are reconciled afterwards.
      def assign_attributes
        # Indifferent access: a host app or importer may pass string keys, and
        # a missed key would send the bulk payload to the association setter.
        attrs = attributes.to_h.with_indifferent_access

        @prices = attrs.key?(:prices) ? attrs[:prices] : nil

        price_list.assign_attributes(attrs.except(:prices))
      end

      def save_price_list
        failure(price_list) unless price_list.save
      end

      def apply_prices
        return if @prices.nil?

        # An empty array means "clear every override on this list", which is a
        # different thing from sending no prices at all.
        return clear_prices if @prices.empty?

        rows = price_rows
        return if rows.empty?

        Spree::Prices::BulkUpsert.call(rows: rows)
        touch_variants(rows.map { |row| row[:variant_id] }.uniq)
      end

      def clear_prices
        variant_ids = price_list.prices.distinct.pluck(:variant_id)
        price_list.prices.update_all(amount: nil, compare_at_amount: nil, updated_at: Time.current)
        touch_variants(variant_ids)
      end

      def price_rows
        Array(@prices).filter_map do |raw|
          row = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h.with_indifferent_access : raw.with_indifferent_access

          # variant_id arrives prefixed from the console and legacy callers,
          # already decoded from a controller that ran normalize_params.
          variant_id = if Spree::PrefixedId.prefixed_id?(row[:variant_id])
                         Spree::PrefixedId.decode_prefixed_id(row[:variant_id])
                       else
                         row[:variant_id]
                       end
          next if variant_id.blank? || row[:currency].blank?

          {
            variant_id: variant_id,
            currency: row[:currency],
            price_list_id: price_list.id,
            amount: row[:amount],
            compare_at_amount: row[:compare_at_amount]
          }
        end
      end

      def touch_variants(variant_ids)
        return if variant_ids.blank?

        Spree::Variants::TouchJob.perform_later(variant_ids)
      end
    end
  end
end
