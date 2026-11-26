module Spree
  module PostSale
    # What the warehouse counted against one line of a return or an exchange.
    #
    # A line can come back in parts: some units resellable and some not, some
    # later than others. `received_quantity` counts every unit that arrived,
    # `resellable_quantity` the ones that went back on the shelf, and
    # `resellable` says whether all of them did.
    module ReceivedLine
      extend ActiveSupport::Concern

      included do
        validates :resellable_quantity, numericality: {
          greater_than_or_equal_to: 0,
          less_than_or_equal_to: ->(line) { line.received_quantity.to_i }
        }
      end

      # A line received before the count was stored has only the flag, and the
      # flag was true only when every unit it received was resellable.
      #
      # @return [Integer]
      def resellable_quantity
        resellable? ? received_quantity.to_i : self[:resellable_quantity].to_i
      end

      # @return [Integer] the received units that cannot be resold
      def unresellable_quantity
        received_quantity.to_i - resellable_quantity
      end

      # @return [Integer] the announced units that have not arrived yet
      def unreceived_quantity
        [quantity.to_i - received_quantity.to_i, 0].max
      end
    end
  end
end
