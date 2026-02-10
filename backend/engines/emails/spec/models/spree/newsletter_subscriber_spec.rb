require 'spec_helper'
describe Spree::NewsletterSubscriber, type: :model, newsletter: true do
  let(:store) { Spree::Store.default }
  let(:subscriber) { create(:newsletter_subscriber) }

  describe '#deliver_newsletter_email_verification' do
    subject(:deliver_newsletter_email_verification) { subscriber.deliver_newsletter_email_verification }

    it 'calls newsletter mailer' do
      expect(Spree::NewsletterMailer).to receive(:email_confirmation).with(subscriber).and_return(double(deliver_later: true))

      deliver_newsletter_email_verification
    end

    context 'when send_consumer_transactional_emails store setting is disabled' do
      before do
        allow(Spree::Current).to receive(:store).and_return(store)
        allow(store).to receive(:prefers_send_consumer_transactional_emails?).and_return(false)
      end

      it 'does not call newsletter mailer' do
        expect(Spree::NewsletterMailer).not_to receive(:email_confirmation)
        deliver_newsletter_email_verification
      end
    end
  end
end
