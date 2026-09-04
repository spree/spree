require 'spec_helper'

RSpec.describe SpreeAvalara::EstimateCacheKey do
  let(:integration) { create(:avalara_integration, store: @default_store) }
  let(:address) { create(:address, city: 'Seattle', state_code: 'WA', country_code: 'US', zipcode: '98109') }
  let(:cart) { create(:cart, store: @default_store, ship_address: address, bill_address: address) }
  let!(:line_item) { create(:line_item, cart: cart, order: nil, price: 100) }

  def key(**overrides)
    described_class.new(
      **{ owner: cart, items: [line_item], integration: integration }.merge(overrides)
    ).key
  end

  it 'is stable for an unchanged request' do
    expect(key).to eq(key)
  end

  it 'names the owner it priced, so two carts never share an entry' do
    other = create(:cart, store: @default_store)

    expect(key).to include(cart.id.to_s)
    expect(key(owner: other, items: [])).not_to eq(key)
  end

  describe 'what changes the answer changes the key' do
    it 'the tax address' do
      before_move = key
      cart.update!(ship_address: create(:address, state_code: 'CA', country_code: 'US', zipcode: '92614'))

      expect(key).not_to eq(before_move)
    end

    # An address change can flip inclusiveness without changing the rate, and
    # serving the previous calculation would state prices the wrong way round.
    it 'the resolved inclusiveness, not the cart market flag' do
      exclusive = key
      allow(SpreeAvalara).to receive(:tax_inclusive?).with(cart).and_return(true)

      expect(key).not_to eq(exclusive)
    end

    it 'the quantity' do
      before_change = key
      line_item.update!(quantity: 3)

      expect(key).not_to eq(before_change)
    end

    it 'the taxable basis' do
      before_change = key
      line_item.update!(price: 250)

      expect(key).not_to eq(before_change)
    end

    # A line item mirrors its variant's tax category on every save, so
    # reclassifying the product is what moves the line.
    it 'the item tax category' do
      before_change = key
      line_item.variant.update!(tax_category: create(:tax_category, store: @default_store, tax_code: 'PC040100'))
      line_item.save!

      expect(key).not_to eq(before_change)
    end

    it 'the buyer registration' do
      identifier = build(:tax_identifier, kind: 'eu_vat', value: 'DE123456789')

      expect(key(tax_identifier: identifier)).not_to eq(key)
    end

    it 'an exemption claim' do
      exemption = Spree::TaxExemption.new(reason_code: 'RESALE', certificate_number: 'C-1')

      expect(key(exemptions: [exemption])).not_to eq(key)
    end

    # Re-pointing the integration at production, or at another company, prices
    # differently under the same credentials.
    it 'the integration company code' do
      before_change = key
      integration.update!(preferred_company_code: 'OTHER')

      expect(key).not_to eq(before_change)
    end
  end
end
