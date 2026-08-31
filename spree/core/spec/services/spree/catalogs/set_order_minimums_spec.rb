require 'spec_helper'

RSpec.describe Spree::Catalogs::SetOrderMinimums do
  let(:store) { @default_store }
  let(:catalog) { create(:catalog, store: store) }

  def apply(rows)
    described_class.call(catalog: catalog, order_minimums: rows)
  end

  it 'creates a minimum for each currency given' do
    apply([{ currency: 'USD', amount: '500' }, { currency: 'EUR', amount: '450' }])

    expect(catalog.order_minimums.reload.pluck(:currency)).to match_array(%w[USD EUR])
  end

  it 'updates a currency already stated rather than duplicating it' do
    create(:catalog_order_minimum, catalog: catalog, currency: 'USD', amount: 500)

    apply([{ currency: 'USD', amount: '750' }])

    expect(catalog.order_minimums.reload.map(&:amount)).to eq([750])
  end

  # The set arrives whole, so a currency left out is one the merchant deleted.
  it 'lifts a minimum absent from the payload' do
    create(:catalog_order_minimum, catalog: catalog, currency: 'USD')
    create(:catalog_order_minimum, catalog: catalog, currency: 'EUR')

    apply([{ currency: 'USD', amount: '500' }])

    expect(catalog.order_minimums.reload.pluck(:currency)).to eq(['USD'])
  end

  it 'lifts every minimum for an empty payload' do
    create(:catalog_order_minimum, catalog: catalog, currency: 'USD')

    apply([])

    expect(catalog.order_minimums.reload).to be_empty
  end

  it 'upcases the currency it is given' do
    apply([{ currency: 'usd', amount: '500' }])

    expect(catalog.order_minimums.reload.pluck(:currency)).to eq(['USD'])
  end

  it 'refuses an amount of zero' do
    expect(apply([{ currency: 'USD', amount: '0' }])).to be_failure
  end
end
