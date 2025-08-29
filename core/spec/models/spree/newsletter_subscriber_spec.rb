require 'spec_helper'
require 'shoulda/matchers'

describe Spree::NewsletterSubscriber, type: :model do
  let(:subscriber) { build(:newsletter_subscriber) }

  describe 'validations' do
    it { expect(subscriber).to validate_presence_of(:email) }
    it { expect(subscriber).to validate_uniqueness_of(:email) }
  end

  describe 'scopes' do
    let!(:verified_subscriber) { create(:newsletter_subscriber, :verified) }
    let!(:unverified_subscriber) { create(:newsletter_subscriber, :unverified) }

    describe 'verified' do
      it { expect(Spree::NewsletterSubscriber.verified).to eq([verified_subscriber]) }
    end

    describe 'unverified' do
      it { expect(Spree::NewsletterSubscriber.unverified).to eq([unverified_subscriber]) }
    end
  end

  describe 'subscribe' do
    subject { described_class.subscribe(email: 'test@example.com') }

    it 'raises NotImplementedError' do
      expect { subject }.to raise_error(NotImplementedError)
    end
  end

  describe 'verify' do
    subject { described_class.verify(token) }

    context 'when subscriber is found' do
      let(:subscriber) { create(:newsletter_subscriber, :unverified) }
      let(:token) { subscriber.verification_token }

      it 'raises NotImplementedError' do
        expect { subject }.to raise_error(NotImplementedError)
      end
    end

    context 'when subscriber is not found' do
      let(:token) { 'invalid-token' }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe 'verified?' do
    it { expect(subscriber.verified?).to eq(false) }

    context 'when email is verified' do
      let!(:verified_subscriber) { create(:newsletter_subscriber, :verified) }

      it { expect(verified_subscriber.verified?).to eq(true) }
    end
  end
end