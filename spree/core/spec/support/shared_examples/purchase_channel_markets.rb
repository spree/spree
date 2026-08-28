# Shared behavior for models that include Spree::Purchase::Market — Cart and
# Order both carry a channel and a market, so both must refuse a market their
# channel does not sell into (docs/plans/6.0-channel-markets.md).
#
# The including example group must define `let(:purchase_factory)` returning
# the factory name, and `let(:store)` returning the store under test.
RSpec.shared_examples 'a purchase constrained to channel-served markets' do
  let(:channel) { create(:channel, store: store) }
  let!(:served) { create(:market, store: store, name: 'Served', currency: 'EUR') }
  let!(:unserved) { create(:market, store: store, name: 'Unserved', currency: 'CHF') }

  before { channel.markets << served }

  it 'accepts a market the channel serves' do
    purchase = build(purchase_factory, store: store, channel: channel, market: served)

    expect(purchase).to be_valid
  end

  it 'refuses a market the channel does not serve' do
    purchase = build(purchase_factory, store: store, channel: channel, market: unserved)

    expect(purchase).not_to be_valid
    expect(purchase.errors[:market]).to be_present
  end

  it 'accepts any market when the channel has no allowlist' do
    open_channel = create(:channel, store: store)

    purchase = build(purchase_factory, store: store, channel: open_channel, market: unserved)

    expect(purchase).to be_valid
  end

  # Jobs and imports build purchases without channel context; the guard must
  # not turn those into validation failures.
  it 'skips the check when there is no channel' do
    purchase = build(purchase_factory, store: store, channel: nil, market: unserved)

    expect(purchase).to be_valid
  end

  it 'defaults to a market the channel serves' do
    purchase = build(purchase_factory, store: store, channel: channel, market: nil)
    purchase.valid?

    expect(channel.serves_market?(purchase.market)).to be true
  end
end
