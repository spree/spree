module Spree
  module Exchanges
    # Withdraws an exchange before the goods arrive. Once received, the
    # merchant holds the customer's items and must either fulfill the
    # replacement or refund.
    class Cancel < Spree::Workflow
      include Spree::PostSale::Cancellation

      hooks :validate, :after_cancel

      # @param exchange [Spree::Exchange]
      # @param only_from [Array<String>, nil] narrows the statuses it may be
      #   cancelled from; the customer passes only `requested`
      # @param reason [String, nil]
      def perform(exchange:, reason: nil, only_from: nil)
        super
        cancel
      end

      private

      def post_sale_record = exchange
      def cancellable_statuses = %w[requested approved]
    end
  end
end
