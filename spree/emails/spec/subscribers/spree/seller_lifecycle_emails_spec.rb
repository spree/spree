# frozen_string_literal: true

require 'spec_helper'

# The unit specs mock the event. This one drives the real workflows, so a
# transition that stops publishing its event — or a subscriber left out of the
# engine's registration list — fails here rather than going quietly unnoticed.
RSpec.describe 'seller lifecycle emails', events: true do
  let(:store) { create(:store) }
  let(:seller) do
    create(:seller, store: store, contact_email: 'seller@example.com', status: 'ready_for_review')
  end

  it 'tells the seller when they are approved' do
    perform_enqueued_jobs do
      expect { Spree::Sellers::Approve.call(seller: seller) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(['seller@example.com'])
    expect(mail.subject).to include(store.name)
  end

  it 'tells the seller when they are suspended' do
    seller.update!(status: 'approved')

    perform_enqueued_jobs do
      expect { Spree::Sellers::Suspend.call(seller: seller, reason: 'Counterfeit goods') }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    # The reason is an internal record, not something the seller is handed.
    expect(ActionMailer::Base.deliveries.last.body.encoded).not_to include('Counterfeit goods')
  end

  it 'tells the applicant when they are rejected' do
    perform_enqueued_jobs do
      expect { Spree::Sellers::Reject.call(seller: seller) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  it 'sends nothing when the store has seller emails switched off' do
    store.update!(preferences: store.preferences.merge(send_seller_transactional_emails: false))

    perform_enqueued_jobs do
      expect { Spree::Sellers::Approve.call(seller: seller) }.
        not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  # Inviting already mails through the invitation rail; a seller email here
  # would be the same news twice.
  it 'sends exactly one email when a seller is invited' do
    pending_seller = create(:seller, store: store, contact_email: 'new@example.com')

    perform_enqueued_jobs do
      expect do
        Spree::Sellers::Invite.call(seller: pending_seller, email: 'new@example.com',
                                    inviter: create(:admin_user))
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
