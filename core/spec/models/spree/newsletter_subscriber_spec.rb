require 'spec_helper'

describe Spree::NewsletterSubscriber, type: :model do
  subject(:subscriber) { build(:newsletter_subscriber, email: email) }

  let(:email) { 'joe#example.com' }

  describe 'normalizations' do
    it { is_expected.to normalize(:email).from(" ME@XYZ.COM\n").to('me@xyz.com') }
    it { is_expected.to normalize(:email).from('').to(nil) }
    it { is_expected.to normalize(:email).from(nil).to(nil) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).ignoring_case_sensitivity }
    it { is_expected.to allow_value('test@example.com').for(:email) }
    it { is_expected.not_to allow_value('test@').for(:email) }
  end

  describe 'scopes' do
    let!(:verified_subscriber) { create(:newsletter_subscriber, :verified) }
    let!(:unverified_subscriber) { create(:newsletter_subscriber, :unverified) }

    describe 'verified' do
      it 'returns verified subscribers only' do
        expect(described_class.verified).to eq([verified_subscriber])
      end
    end

    describe 'unverified' do
      it 'returns unverified subscribers only' do
        expect(described_class.unverified).to eq([unverified_subscriber])
      end
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
    subject { subscriber.verified? }

    context 'when email is not verified' do
      let(:subscriber) { create(:newsletter_subscriber, :unverified) }

      it { is_expected.to be_falsy }
    end

    context 'when email is verified' do
      let(:subscriber) { create(:newsletter_subscriber, :verified) }

      it { is_expected.to be_truthy }
    end
  end
end
