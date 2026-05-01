module Spree
  module Api
    module V3
      # Minimal base; admin extends with full fields. Reservations have no
      # customer-facing exposure today.
      class StockReservationSerializer < BaseSerializer
      end
    end
  end
end
