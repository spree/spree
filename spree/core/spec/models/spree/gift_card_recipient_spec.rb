require 'spec_helper'

RSpec.describe Spree::GiftCardRecipient, type: :model do
  let(:store) { Spree::Store.default }
  let(:line_item) { create(:line_item, product: create(:gift_card_product, store: store)) }

  it 'takes the store of the purchase it belongs to' do
    recipient = described_class.create!(line_item: line_item, email: ' Friend@Example.com ')

    expect(recipient.store).to eq(line_item.order.store)
    expect(recipient.email).to eq('friend@example.com')
  end

  it 'refuses a line that does not buy a gift card' do
    recipient = described_class.new(line_item: create(:line_item), email: 'friend@example.com')

    expect(recipient).not_to be_valid
    expect(recipient.errors.details[:line_item]).to include(error: :not_a_gift_card)
  end

  it 'refuses a send date more than 90 days ahead' do
    recipient = described_class.new(line_item: line_item, email: 'friend@example.com', send_at: 91.days.from_now)

    expect(recipient).not_to be_valid
    expect(recipient.errors.details[:send_at]).to include(error: :too_far_ahead)
  end

  describe '#same_as?' do
    let(:recipient) { described_class.new(email: 'friend@example.com', name: 'Alex', message: 'Hi') }

    it 'compares the payload as it would be stored' do
      expect(recipient.same_as?(email: 'FRIEND@example.com ', name: 'Alex', message: 'Hi')).to be(true)
      expect(recipient.same_as?(email: 'friend@example.com', name: 'Sam', message: 'Hi')).to be(false)
      expect(recipient.same_as?(nil)).to be(false)
    end
  end
end
