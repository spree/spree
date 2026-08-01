require 'spec_helper'

RSpec.shared_examples 'a purchase lifecycle host' do
  describe '#completed? / #complete?' do
    it 'keys on completed_at' do
      expect(new_record(completed_at: Time.current)).to be_completed
      expect(new_record(completed_at: Time.current)).to be_complete
      expect(new_record).not_to be_completed
    end
  end

  describe '#in_checkout?' do
    it 'begins once checkout-only data appears and ends at completion' do
      expect(new_record).not_to be_in_checkout
      expect(new_record(email: 'buyer@example.com')).to be_in_checkout
      expect(new_record(ship_address: create(:address))).to be_in_checkout
      expect(new_record(email: 'buyer@example.com', completed_at: Time.current)).not_to be_in_checkout
    end
  end

  describe '#can_be_deleted?' do
    it 'is true only for an open record without settled payments' do
      expect(new_record).to be_can_be_deleted
      expect(new_record(completed_at: Time.current)).not_to be_can_be_deleted

      record = new_record_with_line_items
      create_payment(record, state: 'completed', amount: record.total)
      expect(record.reload).not_to be_can_be_deleted
    end
  end

  describe '#backordered?' do
    it 'reflects backordered fulfillment items' do
      record = new_record
      allow(record).to receive(:fulfillment_items).and_return([double(backordered?: false), double(backordered?: true)])

      expect(record).to be_backordered
    end
  end

  describe '#guest_checkout_disallowed?' do
    it 'never blocks a signed-in customer' do
      expect(new_record(customer: create(:user)).guest_checkout_disallowed?).to be(false)
    end

    it 'follows the channel guest-checkout flag for guests' do
      record = new_record
      record.valid? # resolve the default channel

      allow(record.channel).to receive(:guest_checkout_enabled?).and_return(false)
      expect(record.guest_checkout_disallowed?).to be(true)

      allow(record.channel).to receive(:guest_checkout_enabled?).and_return(true)
      expect(record.guest_checkout_disallowed?).to be(false)
    end
  end
end

RSpec.describe Spree::Purchase::Lifecycle do
  let(:store) { @default_store }

  context 'included in Spree::Cart' do
    def new_record(customer: nil, **attributes)
      build(:cart, store: @default_store, customer: customer, **attributes)
    end

    def new_record_with_line_items
      create(:cart_with_line_items, store: @default_store)
    end

    def create_payment(record, **attributes)
      create(:payment, cart: record, order: nil, **attributes)
    end

    it_behaves_like 'a purchase lifecycle host'
  end

  context 'included in Spree::Order' do
    def new_record(customer: nil, **attributes)
      build(:order, store: @default_store, user: customer, **attributes)
    end

    def new_record_with_line_items
      create(:order_with_line_items, store: @default_store)
    end

    def create_payment(record, **attributes)
      create(:payment, order: record, **attributes)
    end

    it_behaves_like 'a purchase lifecycle host'
  end
end
