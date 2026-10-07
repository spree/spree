module Spree
  module Claims
    class Cancel < Spree::Workflow
      include Spree::PostSale::Cancellation

      hooks :validate, :after_cancel

      # @param claim [Spree::Claim]
      # @param reason [String, nil]
      def perform(claim:, reason: nil)
        super
        cancel
      end

      private

      def post_sale_record = claim
      def cancellable_statuses = %w[open approved]
    end
  end
end
