require 'spec_helper'
describe Spree::NewsletterSubscriber, type: :model do
  let(:subscriber) { create(:newsletter_subscriber) }

  describe '#deliver_newsletter_email_verification' do
    subject(:deliver_newsletter_email_verification) { subscriber.deliver_newsletter_email_verification }

    it 'calls newsletter mailer' do
      expect(Spree::NewsletterMailer).to receive(:email_confirmation).with(subscriber).and_return(double(deliver_later: true))

      deliver_newsletter_email_verification
    end
  end
end
