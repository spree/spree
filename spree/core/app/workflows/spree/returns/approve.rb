module Spree
  module Returns
    # Authorizes a requested return.
    #
    # No return-label generation here: a prepaid label is carrier output, and
    # every comparable platform treats it as fulfillment-provider data rather
    # than state on the return (Medusa returns `label_url` on a fulfillment,
    # Saleor's Fulfillment carries only a tracking number, Vendure has no
    # return-label concept at all). It arrives with the carrier provider in
    # 6.0-delivery-rate-provider.md; a store needing one before then can put
    # the URL in the return's `metadata`.
    class Approve < Spree::Workflow
      include Spree::PostSale::Approval

      hooks :validate, :after_approve

      # @param return_record [Spree::Return]
      # @param approver [Object, nil] who is approving it (see Spree.actor_classes)
      def perform(return_record:, approver: nil)
        super
        approve
      end

      private

      def post_sale_record = return_record
      def approvable_status = 'requested'
    end
  end
end
