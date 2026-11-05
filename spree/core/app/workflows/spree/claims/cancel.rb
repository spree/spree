module Spree
  module Claims
    class Cancel < Spree::Workflow
      include Spree::PostSale::Cancellation

      hooks :validate, :after_cancel

      # @param claim [Spree::Claim]
      # @param only_from [Array<String>, nil] narrows the statuses it may be
      #   cancelled from; the customer passes only `requested`
      # @param reason [String, nil]
      def perform(claim:, reason: nil, only_from: nil)
        super
        cancel
      end

      private

      def post_sale_record = claim
      def cancellable_statuses = %w[open approved]
    end
  end
end
