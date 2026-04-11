module Spree
  module Cart
    class Update
      prepend Spree::ServiceModule::Base

      def call(order:, params:)
        return failure(order) unless order.update(filter_order_items(order, params))

        order.line_items = order.line_items.select { |li| li.quantity > 0 }
        # Update totals, then check if the order is eligible for any cart promotions.
        # If we do not update first, then the item total will be wrong and ItemTotal
        # promotion rules would not be triggered.
        ActiveRecord::Base.transaction do
          order.update_with_updater!
          ::Spree::PromotionHandler::Cart.new(order).activate
          order.ensure_updated_shipments
          order.payments.store_credits.checkout.destroy_all
          order.update_with_updater!
        end
        success(order)
      end

      private

      def filter_order_items(order, params)
        line_items_attrs = params[:line_items_attributes]
        return params if line_items_attrs.nil?

        line_item_ids = order.line_item_ids.map(&:to_s)
        normalized = normalize_line_items_attributes(line_items_attrs)

        filtered =
          if normalized.is_a?(Array)
            normalized.select { |value| keep_line_item?(value, line_item_ids) }
          else
            # Preserve the id-only shortcut: a single unwrapped entry
            # like `{id: X, quantity: 0}` skips filtering entirely.
            return params if normalized[:id]

            normalized.each_with_object({}) do |(key, value), acc|
              acc[key] = value if keep_line_item?(value, line_item_ids)
            end
          end

        params.merge(line_items_attributes: filtered)
      end

      # Plain Hashes from JSON or manually-built callers may use string keys,
      # which would silently bypass the symbol-keyed lookups below. Normalize
      # to indifferent access at the entry so both key styles behave the same.
      def normalize_line_items_attributes(attrs)
        if attrs.is_a?(Array)
          attrs.map { |value| indifferent(value) }
        else
          indifferent(attrs)
        end
      end

      def indifferent(value)
        return value unless value.is_a?(Hash)

        value.with_indifferent_access
      end

      def keep_line_item?(value, line_item_ids)
        line_item_ids.include?(value[:id].to_s) || value[:variant_id].present?
      end
    end
  end
end
