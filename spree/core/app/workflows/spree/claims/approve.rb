module Spree
  module Claims
    class Approve < Spree::Workflow
      include Spree::PostSale::Approval

      hooks :validate, :after_approve

      # @param claim [Spree::Claim]
      # @param approver [Object, nil]
      def perform(claim:, approver: nil)
        super
        approve
      end

      private

      def post_sale_record = claim
      def approvable_status = 'open'
    end
  end
end
