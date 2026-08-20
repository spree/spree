module Spree
  module PriceLists
    # Updates a price list and applies the bulk payloads that ride with it:
    # which products the list covers, and the individual price overrides.
    #
    # Those used to be attribute writers that stashed their input and
    # after_save callbacks that applied it — a multi-step flow disguised as an
    # assignment, where the order the callbacks happened to run in was
    # load-bearing (membership has to settle before prices, so a newly added
    # product has a row to overwrite). Here that order is the step order, and a
    # handler can veto the whole edit before any of it is written.
    class Update < Spree::Workflow
      hooks :validate, :after_update

      # @param price_list [Spree::PriceList]
      # @param attributes [Hash] may carry `product_ids` and `prices`
      # @return [Spree::ServiceModule::Result] value is the price list
      def perform(price_list:, attributes: {})
        super

        step :assign_attributes
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_price_list
          step :apply_product_ids
          step :apply_prices
          run_hooks :after_update
        end

        success(price_list)
      end

      private

      # The bulk payloads are held back rather than assigned, so the record
      # saves as a plain row and the collections are reconciled afterwards.
      def assign_attributes
        @product_ids = attributes.key?(:product_ids) ? Array(attributes[:product_ids]).compact.uniq : nil
        @prices = attributes.key?(:prices) ? attributes[:prices] : nil

        price_list.assign_attributes(attributes.except(:product_ids, :prices))
      end

      def save_price_list
        failure(price_list) unless price_list.save
      end

      def apply_product_ids
        return if @product_ids.nil?

        current = price_list.product_ids
        to_remove = current - @product_ids
        to_add = @product_ids - current
        return if to_remove.empty? && to_add.empty?

        price_list.remove_products(to_remove) if to_remove.any?
        price_list.add_products(to_add) if to_add.any?

        # Membership changes through raw upsert_all/delete_all on prices, which
        # leaves the variants and products caches holding the old set — a
        # same-request read, such as the serializer's product_ids, would still
        # report the membership from before the edit.
        price_list.association(:variants).reset
        price_list.association(:products).reset
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
