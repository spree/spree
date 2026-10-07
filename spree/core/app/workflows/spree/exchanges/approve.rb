module Spree
  module Exchanges
    class Approve < Spree::Workflow
      include Spree::PostSale::Approval

      hooks :validate, :after_approve

      # @param exchange [Spree::Exchange]
      # @param approver [Object, nil]
      def perform(exchange:, approver: nil)
        super
        approve
      end

      private

      def post_sale_record = exchange
      def approvable_status = 'requested'
    end
  end
end
