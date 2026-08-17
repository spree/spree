require 'spec_helper'

RSpec.describe Spree::Seeds::CommissionRates do
  let(:store) { @default_store }

  it 'gives the store a catch-all rate' do
    described_class.call

    rate = store.commission_rates.find_by(code: described_class::DEFAULT_CODE)

    expect(rate).to be_present
    expect(rate).to be_global
  end

  # A marketplace that has not set its terms should charge nothing, rather
  # than a number core invented on its behalf.
  it 'leaves it switched off, charging nothing' do
    described_class.call

    rate = store.commission_rates.find_by(code: described_class::DEFAULT_CODE)

    expect(rate.enabled).to be false
    expect(rate.value).to be_zero
  end

  # The catch-all matches every sale, so anything below it is unreachable.
  # A rate added afterwards has to land above it to take effect at all.
  it 'sits below the rates an operator adds later' do
    described_class.call
    seeded = store.commission_rates.find_by(code: described_class::DEFAULT_CODE)
    added = create(:commission_rate, store: store)

    expect(store.commission_rates.ordered.to_a).to eq([added, seeded])
  end

  # The catch-all matches every sale, so anywhere but the bottom leaves the
  # rates below it unreachable — including on a store that already had some
  # when this ran.
  it 'lands below rates the store already had' do
    existing = create(:commission_rate, store: store)

    described_class.call

    seeded = store.commission_rates.find_by(code: described_class::DEFAULT_CODE)
    expect(store.commission_rates.ordered.to_a).to eq([existing, seeded])
  end

  it 'seeds every store' do
    other_store = create(:store)

    described_class.call

    expect(other_store.commission_rates.where(code: described_class::DEFAULT_CODE)).to exist
  end

  it 'is idempotent' do
    described_class.call

    expect { described_class.call }.not_to change(Spree::CommissionRate, :count)
  end

  # A store with no catch-all has rates that resolve to nothing below the last
  # targeted one, so the fallback comes back rather than being gone for good —
  # matching the partial unique index, which only constrains live rows.
  it 'restores a deleted default on the next run' do
    described_class.call
    store.commission_rates.find_by(code: described_class::DEFAULT_CODE).destroy

    described_class.call

    restored = store.commission_rates.find_by(code: described_class::DEFAULT_CODE)
    expect(restored).to be_present
    expect(store.commission_rates.ordered.last).to eq(restored)
  end
end
