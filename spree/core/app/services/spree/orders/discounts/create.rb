module Spree
  module Orders
    module Discounts
      # Creates manual (admin-issued) discount rows on an order and re-sums its
      # totals — the sanctioned post-placement discount path. A line-item target
      # gets a single row; an order-level discount is distributed across line
      # items largest-remainder over their discounted bases (there are no
      # order-attached discount rows). Amounts are clamped so no line goes
      # below zero.
      class Create
        prepend Spree::ServiceModule::Base

        # @param order [Spree::Order]
        # @param label [String]
        # @param value [Numeric] positive magnitude ("10" = 10 off / 10 percent off)
        # @param value_type [String] 'flat' or 'percent'
        # @param line_item [Spree::LineItem, nil] nil distributes order-level
        # @return [Spree::ServiceModule::Result] value is the created rows
        def call(order:, label:, value:, value_type: 'flat', line_item: nil)
          value = BigDecimal(value.to_s)
          return failure(nil, I18n.t('spree.errors.messages.discount_value_must_be_positive')) unless value.positive?
          return failure(nil, I18n.t('spree.errors.messages.discount_value_type_invalid')) unless %w[flat percent].include?(value_type)

          rows = order.with_lock do
            created = line_item ? [line_item_row(order, line_item, label, value, value_type)].compact : distributed_rows(order, label, value, value_type)
            if created.any?
              Spree.order_recalculate_totals_workflow.call(order: order)
              order.update_statuses!
            end
            created
          end

          return failure(nil, I18n.t('spree.errors.messages.discount_has_no_effect')) if rows.empty?

          success(rows)
        end

        private

        def line_item_row(order, line_item, label, value, value_type)
          base = discountable_base(line_item)
          amount = -[amount_for(base, value, value_type, order.currency), base].min
          return if amount.zero?

          create_row(order, line_item, label, amount, value, value_type)
        end

        def distributed_rows(order, label, value, value_type)
          line_items = order.line_items.to_a
          bases = line_items.map { |line_item| [discountable_base(line_item), BigDecimal(0)].max }
          bases_sum = bases.sum
          return [] if bases_sum <= 0

          total = [amount_for(bases_sum, value, value_type, order.currency), bases_sum].min
          total_units = Spree::Money::Rounding.to_minor_units(total, order.currency)
          shares = Spree::Adjusters::LargestRemainder.largest_remainder_shares(total_units, bases)

          line_items.each_with_index.filter_map do |line_item, index|
            amount = -Spree::Money::Rounding.from_minor_units(shares[index], order.currency)
            next if amount.zero?

            create_row(order, line_item, label, amount, value, value_type)
          end
        end

        def amount_for(base, value, value_type, currency)
          value_type == 'percent' ? Spree::Money::Rounding.to_currency(base * value / 100, currency) : value
        end

        # Remaining discountable base: amount net of already-applied discounts.
        def discountable_base(line_item)
          line_item.amount + line_item.owner.discounts.where(line_item_id: line_item.id).sum(:amount)
        end

        def create_row(order, line_item, label, amount, value, value_type)
          order.discounts.create!(
            line_item: line_item,
            label: label,
            amount: amount,
            kind: 'manual',
            value: value,
            value_type: value_type
          )
        end
      end
    end
  end
end
