require 'spec_helper'

RSpec.describe SpreeAvalara::TransactionPresenter do
  let(:integration) { build(:avalara_integration, store: @default_store, preferred_company_code: 'SPARK') }
  let(:address) { create(:address, city: 'Seattle', state_code: 'WA', country_code: 'US', zipcode: '98109') }
  let(:cart) { create(:cart, store: @default_store, email: 'buyer@example.com', ship_address: address, bill_address: address) }
  let!(:line_item) { create(:line_item, cart: cart, order: nil, price: 40) }

  def present(**overrides)
    described_class.new(
      **{ owner: cart, integration: integration, items: [line_item], type: 'SalesOrder' }.merge(overrides)
    ).call
  end

  it 'describes the sale Avalara is being asked about' do
    payload = present

    expect(payload[:type]).to eq('SalesOrder')
    expect(payload[:companyCode]).to eq('SPARK')
    expect(payload[:currencyCode]).to eq(cart.currency)
    expect(payload[:lines].map { |line| line[:number] }).to eq([line_item.prefixed_id])
  end

  # commit is meaningful precisely when false, so it must survive payload
  # construction rather than being compacted away as blank.
  it 'always states whether the document is committed' do
    expect(present).to have_key(:commit)
    expect(present[:commit]).to be(false)
    expect(present(commit: true)[:commit]).to be(true)
  end

  describe 'the document code' do
    # A quote is not a document, so Avalara assigns its own code.
    it 'is left to Avalara for a quote' do
      expect(present).not_to have_key(:code)
    end

    it 'is the order number when filing' do
      expect(present(type: 'SalesInvoice', code: 'R1001')[:code]).to eq('R1001')
    end
  end

  describe 'the buyer registration' do
    it 'is sent when the sale has one' do
      identifier = build(:tax_identifier, kind: 'eu_vat', value: 'DE123456789')

      expect(present(tax_identifier: identifier)[:businessIdentificationNo]).to eq('DE123456789')
    end

    # Absent means consumer sale, which is the legally safe default; sending an
    # empty string would claim a registration that does not exist.
    it 'is omitted for a consumer sale' do
      expect(present).not_to have_key(:businessIdentificationNo)
    end
  end

  describe 'addresses' do
    it 'ships to the tax address rather than re-deriving one' do
      expect(present[:addresses][:shipTo]).to include(city: 'Seattle', region: 'WA', postalCode: '98109')
    end

    it 'omits an origin the sale has no fulfillment for' do
      expect(present[:addresses]).not_to have_key(:shipFrom)
    end
  end

  describe 'the document date' do
    # A merchant closing a sale late on the 31st means their 31st.
    it 'is read in the store timezone' do
      @default_store.update!(preferred_timezone: 'Australia/Sydney')
      late_utc = Time.utc(2026, 8, 31, 20, 0, 0)

      expect(present(tax_date: late_utc)[:date]).to eq('2026-09-01')
    end

    it 'defaults to today when the caller names no date' do
      expect(present[:date]).to eq(Time.current.in_time_zone(@default_store.preferred_timezone).to_date.iso8601)
    end
  end

  it 'prices every line against the resolved inclusiveness, not the cart market' do
    allow(SpreeAvalara).to receive(:tax_inclusive?).with(cart).and_return(true)

    expect(present[:lines].map { |line| line[:taxIncluded] }).to eq([true])
  end
end
