require 'spec_helper'

RSpec.describe Spree::CSV::NewsletterSubscriberPresenter do
  let(:user) do
    create(
      :user,
      first_name: 'Alice',
      last_name: 'Wonderland',
      email: 'alice@example.com'
    )
  end

  let(:newsletter_subscriber) do
    create(
      :newsletter_subscriber,
      email: 'subscriber@example.com',
      user: user,
      user_id: user.id,
      verified_at: Time.current.change(usec: 0),
      created_at: 2.days.ago.change(usec: 0),
      updated_at: 1.day.ago.change(usec: 0)
    )
  end

  let(:presenter) { described_class.new(newsletter_subscriber) }

  describe '#call' do
    subject(:row) { presenter.call }

    it 'returns array with correct values' do
      expect(row[0]).to eq newsletter_subscriber.email
      expect(row[1]).to eq user.full_name
      expect(row[2]).to eq user.id
      expect(row[3]).to eq Spree.t(:say_yes)
      expect(row[4]).to eq newsletter_subscriber.verified_at
      expect(row[5]).to eq newsletter_subscriber.created_at
      expect(row[6]).to eq newsletter_subscriber.updated_at
    end

    context 'when subscriber is not verified' do
      before { newsletter_subscriber.update!(verified_at: nil) }

      it 'returns say_no for verified and nil for verified_at' do
        expect(row[3]).to eq Spree.t(:say_no)
        expect(row[4]).to be_nil
      end
    end

    context 'when subscriber has no user' do
      let(:newsletter_subscriber) do
        create(
          :newsletter_subscriber,
          email: 'nouser@example.com',
          user: nil,
          user_id: nil,
          verified_at: nil,
          created_at: 3.days.ago.change(usec: 0),
          updated_at: 2.days.ago.change(usec: 0)
        )
      end

      it 'returns nil for customer name and id' do
        expect(row[1]).to be_nil
        expect(row[2]).to be_nil
      end
    end
  end

  describe 'HEADERS constant' do
    it 'contains all expected headers' do
      expected_headers = [
        'Email',
        'Customer Name',
        'Customer ID',
        'Verified',
        'Verified At',
        'Created At',
        'Updated At'
      ]
      expect(described_class::HEADERS).to eq(expected_headers)
    end
  end
end
