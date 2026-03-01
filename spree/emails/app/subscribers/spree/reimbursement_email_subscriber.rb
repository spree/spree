# frozen_string_literal: true

module Spree
  class ReimbursementEmailSubscriber < Spree::Subscriber
    subscribes_to 'reimbursement.reimbursed'

    def handle(event)
      reimbursement = find_reimbursement(event)
      return unless reimbursement

      store = reimbursement.store
      return unless store.prefers_send_consumer_transactional_emails?

      ReimbursementMailer.reimbursement_email(reimbursement.id).deliver_later
    end

    private

    def find_reimbursement(event)
      reimbursement_id = event.payload['id']
      Spree::Reimbursement.find_by_prefix_id(reimbursement_id)
    end
  end
end
