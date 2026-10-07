require 'spec_helper'

describe Spree::CompanyEmailSubscriber do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }

  def handle(invitation)
    event = instance_double(Spree::Event, payload: { 'id' => invitation.prefixed_id })
    described_class.new.handle(event)
  end

  it 'mails the invite when an invitation is created' do
    invitation = create(:company_invitation, company: company)

    expect {
      handle(invitation)
    }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with(
      'Spree::CompanyMailer', 'invitation_email', 'deliver_now', args: [invitation.id]
    )
  end

  it 'stays silent for an invitation that is no longer pending' do
    invitation = create(:company_invitation, company: company)
    invitation.revoke!

    expect { handle(invitation) }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end

  it 'stays silent when the store has consumer transactional emails off' do
    invitation = create(:company_invitation, company: company)
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))

    expect { handle(invitation) }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end

  it 'mails the invite through the registered subscribers', events: true do
    perform_enqueued_jobs do
      expect { create(:company_invitation, company: company, email: 'buyer@example.com') }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    expect(ActionMailer::Base.deliveries.last.to).to eq(['buyer@example.com'])
  end
end
