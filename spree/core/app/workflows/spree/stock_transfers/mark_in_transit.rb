module Spree
  module StockTransfers
    # The van has left. This is the moment stock leaves the source warehouse:
    # `shipped` movements are written against the source's levels, and the
    # units are in flight until the destination counts them in.
    #
    # The destination is deliberately untouched. A merchant who marked a
    # transfer in transit yesterday should see the source short and the
    # destination unchanged — that is what the 5.x one-shot transfer could not
    # express, and why availability was wrong for the whole journey.
    class MarkInTransit < Spree::Workflow
      hooks :validate, :before_unstock, :after_mark_in_transit

      # @param stock_transfer [Spree::StockTransfer]
      # @param force [Boolean] ship even if it drives the source below zero.
      #   A merchant forcing a departure has decided the box left whatever the
      #   ledger claims.
      def perform(stock_transfer:, force: false)
        super

        step :ensure_shippable
        step :ensure_source_has_stock unless force
        run_hooks :validate

        ApplicationRecord.transaction do
          run_hooks :before_unstock
          step :write_shipped_movements
          step :mark_in_transit
        end

        run_hooks :after_mark_in_transit
        stock_transfer.publish_event('stock_transfer.shipped')
        success(stock_transfer.reload)
      end

      private

      def ensure_shippable
        unless stock_transfer.draft? || stock_transfer.ready_to_ship?
          failure(stock_transfer, Spree.t('stock_transfer.errors.not_shippable'))
        end
        failure(stock_transfer, Spree.t('stock_transfer.errors.must_have_variant')) if stock_transfer.items.empty?
      end

      # Every line needs enough available stock for the quantity being moved,
      # not merely some: without the per-line check a transfer takes more than
      # the shelf holds and leaves it negative.
      def ensure_source_has_stock
        source = stock_transfer.source_location

        unavailable_items = stock_transfer.items.select do |item|
          level = source.stock_level(item.variant_id)
          level.nil? || level.available_count < item.quantity_shipped
        end

        return if unavailable_items.empty?

        failure(stock_transfer,
                Spree.t('stock_transfer.errors.variants_unavailable', stock: source.name))
      end

      def write_shipped_movements
        source = stock_transfer.source_location

        stock_transfer.items.each do |item|
          source.unstock(item.variant, item.quantity_shipped, stock_transfer, force: force)
        end
      end

      def mark_in_transit
        failure(stock_transfer) unless stock_transfer.update(status: 'in_transit', shipped_at: Time.current)
      end
    end
  end
end
