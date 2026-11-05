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

  it "publishes inside the order's store" do
    other_store = create(:store)
    other_order = create(:completed_order_with_totals, store: other_store).tap { |o| o.update_columns(email: 'guest@example.com') }
    seen_store = nil
    allow(Spree::Events).to receive(:publish).and_wrap_original do |original, *args, **kwargs|
      seen_store = Spree::Current.store if args.first == 'order.lookup_requested'
      original.call(*args, **kwargs)
    end

    described_class.perform_now(other_store.id, other_order.number, 'guest@example.com')

    expect(seen_store).to eq(other_store)
  end
end
