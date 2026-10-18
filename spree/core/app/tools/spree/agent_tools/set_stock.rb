module Spree
  module AgentTools
    # Sets how many of something is on a shelf, through the Admin API's own
    # bulk endpoint.
    #
    # Named for what a merchant says — "forty in stock", "two fewer, damaged"
    # — rather than for the operation. Either an absolute figure or a signed
    # change, per variant and location, as many at once as the merchant has
    # counted.
    class SetStock < Spree::AgentTool
      tool_name 'set_stock'
      description 'Set how many units are on hand, or adjust by a difference. Each row names ' \
                  'a variant and a stock location, then either count_on_hand (the figure it ' \
                  'should end at) or adjustment (a signed change). Give a reason so the stock ' \
                  'history explains it.'
      permission 'write_stock'
      mutating!

      param :rows, type: :array, items: :object, required: true,
                   description: 'One per shelf: {"variant_id": "variant_x", ' \
                                '"stock_location_id": "sl_y", "count_on_hand": 40, ' \
                                '"reason": "received"}'

      def call(rows:)
        prepared = Array(rows).map { |row| row.respond_to?(:to_h) ? row.to_h.stringify_keys : {} }
        return { error: 'Give at least one row.' } if prepared.empty?

        response = ApiDispatch.new(context).call(
          method: :post, path: '/api/v3/admin/stock_levels/bulk_upsert', body: { stock_levels: prepared }
        )

        unless response.success?
          # The endpoint names the missing field per row, which is what lets a
          # model repair its own request rather than resend it whole.
          rows = response.body.is_a?(Hash) ? response.body.dig('error', 'details', 'rows') : nil

          return { error: response.error_message, rows: rows }.compact
        end

        changed = response.body.is_a?(Hash) ? response.body['stock_level_count'] : nil

        { ok: true, shelves_changed: changed || prepared.size }
      end

      def summary(arguments)
        count = Array(arguments[:rows]).size

        "Set stock on #{count} #{'shelf'.pluralize(count)}"
      end
    end
  end
end
