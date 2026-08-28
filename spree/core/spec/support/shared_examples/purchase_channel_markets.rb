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

  # A channel is a surface of one store, so an explicitly supplied foreign
  # channel must be refused at the model rather than by whichever service
  # happened to build the record.
  it 'refuses a channel belonging to another store' do
    foreign_channel = create(:channel, store: create(:store))

    purchase = build(purchase_factory, store: store, channel: foreign_channel)

    expect(purchase).not_to be_valid
    expect(purchase.errors[:channel]).to be_present
  end

  it 'refuses a market belonging to another store' do
    foreign = create(:market, store: create(:store))

    purchase = build(purchase_factory, store: store, channel: channel, market: foreign)

    expect(purchase).not_to be_valid
    expect(purchase.errors[:market]).to be_present
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

  # Changing currency re-resolves the market; the candidates must come from
  # the allowlist, or the purchase would resolve into a market its own
  # validation rejects.
  it 'resolves a currency change within the served markets' do
    purchase = create(purchase_factory, store: store, channel: channel, market: served)

    purchase.update(currency: unserved.currency)

    expect(purchase.market).to eq(served)
  end
end
