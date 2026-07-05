module Spree
  module StockReservations
    class ExpireJob < Spree::BaseJob
      queue_as Spree.queues.stock_reservations

      def perform
        Spree::StockReservation.expired.in_batches(of: 1_000).delete_all
      end
    end
  end
end
