# frozen_string_literal: true

require 'spec_helper'

# The unit specs mock the event. This one drives the real workflows, so a
# transition that stops publishing its event — or a subscriber left out of the
# engine's registration list — fails here rather than going quietly unnoticed.
RSpec.describe 'vendor lifecycle emails', events: true do
  let(:store) { create(:store) }
  let(:vendor) do
    create(:vendor, store: store, contact_email: 'seller@example.com', status: 'ready_for_review')
  end

  it 'tells the seller when they are approved' do
    perform_enqueued_jobs do
      expect { Spree::Vendors::Approve.call(vendor: vendor) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(['seller@example.com'])
    expect(mail.subject).to include(store.name)
  end

  it 'tells the seller when they are suspended' do
    vendor.update!(status: 'approved')

    perform_enqueued_jobs do
      expect { Spree::Vendors::Suspend.call(vendor: vendor, reason: 'Counterfeit goods') }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    # The reason is an internal record, not something the seller is handed.
    expect(ActionMailer::Base.deliveries.last.body.encoded).not_to include('Counterfeit goods')
  end

  it 'tells the applicant when they are rejected' do
    perform_enqueued_jobs do
      expect { Spree::Vendors::Reject.call(vendor: vendor) }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  it 'sends nothing when the store has vendor emails switched off' do
    store.update!(preferences: store.preferences.merge(send_vendor_transactional_emails: false))

    perform_enqueued_jobs do
      expect { Spree::Vendors::Approve.call(vendor: vendor) }.
        not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  # Inviting already mails through the invitation rail; a vendor email here
  # would be the same news twice.
  it 'sends exactly one email when a vendor is invited' do
    pending_vendor = create(:vendor, store: store, contact_email: 'new@example.com')

    perform_enqueued_jobs do
      expect do
        Spree::Vendors::Invite.call(vendor: pending_vendor, email: 'new@example.com',
                                    inviter: create(:admin_user))
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
