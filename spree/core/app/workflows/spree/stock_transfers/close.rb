module Spree
  module StockTransfers
    # Ends a transfer whose missing units are not going to turn up.
    #
    # Eight of ten arrived and the box is not coming back for the other two.
    # The units already left the source when the transfer went in transit, so
    # nothing is written to any shelf: closing short keeps what the
    # destination counted in, records why the rest never arrived, and leaves
    # the outstanding count on each line as the record of the loss.
    class Close < Spree::Workflow
      include Spree::Receivables::ClosingShort

      hooks :validate, :after_close

      attr_reader :stock_transfer, :reason

      # @param stock_transfer [Spree::StockTransfer]
      # @param reason [String, nil] what happened to the balance
      def perform(stock_transfer:, reason: nil)
        super
        close
      end

      private

      def receivable = stock_transfer
    end
  end
end
