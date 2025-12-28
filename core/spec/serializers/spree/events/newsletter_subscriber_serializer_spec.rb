# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::NewsletterSubscriberSerializer do
  let(:subscriber) do
    create(:newsletter_subscriber,
           email: 'test@example.com',
           verified_at: Time.zone.parse('2024-01-15 10:30:00'))
  end

  subject { described_class.serialize(subscriber) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(subscriber.id)
      expect(subject[:email]).to eq('test@example.com')
    end

    it 'includes verified status' do
      expect(subject[:verified]).to be true
      expect(subject[:verified_at]).to eq('2024-01-15T10:30:00Z')
    end

    it 'includes user_id' do
      expect(subject).to have_key(:user_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end

    context 'when not verified' do
      let(:subscriber) { create(:newsletter_subscriber, verified_at: nil) }

      it 'returns verified as false' do
        expect(subject[:verified]).to be false
        expect(subject[:verified_at]).to be_nil
      end
    end
  end
end
