require 'spec_helper'

RSpec.describe Spree::Orders::LookupJob, events: true do
  let(:store) { @default_store }
  let!(:order) { create(:completed_order_with_totals, store: store).tap { |o| o.update_columns(email: 'guest@example.com') } }

  before { allow(Spree::Events).to receive(:publish).and_call_original }

  it 'announces a match, ignoring case and spaces' do
    described_class.perform_now(store.id, " #{order.number.downcase} ", 'Guest@Example.com')

    # The payload's shape is the API's (OrderLookupRequestedEventSerializer).
    expect(Spree::Events).to have_received(:publish).with('order.lookup_requested', anything, anything)
  end

  it 'stays silent on a wrong email' do
    described_class.perform_now(store.id, order.number, 'someone@example.com')

    expect(Spree::Events).not_to have_received(:publish).with('order.lookup_requested', anything, anything)
  end

  it "does not reach another store's order" do
    described_class.perform_now(create(:store).id, order.number, 'guest@example.com')

    expect(Spree::Events).not_to have_received(:publish).with('order.lookup_requested', anything, anything)
  end
end
