module Spree
  module StockReservations
    class ExpireJob < Spree::BaseJob
      queue_as Spree.queues.stock_reservations

      def perform
        Spree::StockReservation.sweep_expired
      end
    end
  end
end
