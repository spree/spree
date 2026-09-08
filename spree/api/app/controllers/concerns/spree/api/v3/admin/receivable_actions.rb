module Spree
  module Api
    module V3
      module Admin
        # What a stock transfer and a purchase order have in common as
        # endpoints: resolving the lines, warehouses and variants a flat
        # payload names (docs/plans/6.0-inventory-operations.md). The status
        # workflows themselves are run by the actions, which is where the
        # keyword each one takes the document under stays visible.
        #
        # Every id a payload names is resolved through the store — or through
        # the document itself, for its own lines — so an id belonging to
        # another tenant answers 404 rather than being acted on. That is also
        # why nothing here assigns a `*_id` from the payload, and why the lines
        # come from the raw payload rather than `permitted_params`: the latter
        # decodes prefixed ids into primary keys, and a decoded key carries no
        # evidence of whose record it is.
        module ReceivableActions
          extend ActiveSupport::Concern
          include Spree::Api::V3::ItemsPayload

          protected

          # What rendering a line actually reads: the variant, the product it
          # belongs to — for the name and the link — and whichever image the
          # thumbnail falls back to, with the blobs the URL helper needs.
          def line_includes
            media = { primary_media: [attachment_attachment: :blob, poster_attachment: :blob] }
            { items: { variant: [media, { product: media }] } }
          end

          # The lines a create or update named, or nil when the payload said
          # nothing about them — which on an update means "leave them alone".
          #
          # @param attribute_keys [Array<Symbol>] the per-line attributes this
          #   document accepts beyond the variant (`:quantity_shipped`,
          #   `:quantity_ordered`, `:unit_cost`)
          # @return [Array<Hash>, nil]
          def items_from_params(*attribute_keys)
            sent = items_payload([:variant_id, *attribute_keys])
            return nil if sent.nil?

            sent.map do |item|
              attributes = { variant: variants_scope.find_by_prefix_id!(item[:variant_id]) }
              attribute_keys.each { |key| attributes[key] = item[key] if item.key?(key.to_s) }
              attributes
            end
          end

          # What the warehouse counted, resolved through the document itself,
          # so a line from another transfer or order cannot be received here.
          #
          # An omitted `items` means "receive it all as expected". Naming an
          # empty list — or an explicit `null`, the same statement — means the
          # caller named no lines, and must not fall through to receive-all.
          #
          # @param keys [Array<Symbol>] the per-line keys to permit
          # @return [Array<Hash>, nil]
          def items_for_receive(keys)
            sent = items_payload(keys)
            return nil if sent.nil?

            sent.map do |item|
              received = {
                item: @resource.items.find_by_prefix_id!(item[:id]),
                quantity_received: item[:quantity_received]
              }
              # Only when the payload actually carried one: a second receive
              # that tops a line up without repeating the reason must not erase
              # the audit text the first one recorded.
              received[:discrepancy_reason] = item[:discrepancy_reason] if item.key?('discrepancy_reason')
              received
            end
          end

          # Any of the store's warehouses the caller may see, or nil when the
          # payload did not name one.
          #
          # @return [Spree::StockLocation, nil]
          def stock_location_from(key)
            id = params[key]
            return nil if id.blank?

            current_store.stock_locations.accessible_by(current_ability, :show).find_by_prefix_id!(id)
          end

          def variants_scope
            current_store.variants.accessible_by(current_ability, :show)
          end
        end
      end
    end
  end
end
