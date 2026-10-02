module Spree
  module Exchanges
    # Withdraws an exchange before the goods arrive. Once received, the
    # merchant holds the customer's items and must either fulfill the
    # replacement or refund.
    class Cancel < Spree::Workflow
      include Spree::PostSale::Cancellation

      hooks :validate, :after_cancel

      # @param exchange [Spree::Exchange]
      # @param reason [String, nil]
      def perform(exchange:, reason: nil)
        super
        cancel
      end

      private

      def post_sale_record = exchange
      def cancellable_statuses = %w[requested approved]
    end
  end
end
