# frozen_string_literal: true

module Spree
  # Takes back the refunds a store credit paid when the credit is withdrawn.
  #
  # Credit given back for an order is recorded as refunds against its
  # payments. A merchant may still delete such a credit before the customer
  # spends it, and then the order gave nothing back after all: the refunds
  # are marked failed, which is how every reader of refunds already treats
  # money that did not go back. `refund.failed` then moves the split share
  # and the order's payment total and status, as for a gateway refund.
  #
  # Synchronous, like the status subscriber, so the order reads right as soon
  # as the credit is gone.
  class StoreCreditRefundSubscriber < Spree::Subscriber
    subscribes_to 'store_credit.deleted', async: false

    def handle(event)
      credit = Spree::StoreCredit.with_deleted.find_by_prefix_id(event.payload['id'])
      return if credit.nil? || !credit.deleted?

      credit.refunds.not_failed.find_each do |refund|
        refund.update!(status: 'failed', failure_reason: I18n.t('spree.store_credit_withdrawn'))
        refund.publish_event('refund.failed')
      end
    end
  end
end
