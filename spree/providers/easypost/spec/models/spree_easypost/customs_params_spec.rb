require 'spec_helper'

RSpec.describe 'SpreeEasyPost customs params' do
  let(:store) { @default_store }
  # Countries are reference data since 6.0 — looked up, never created.
  let(:usa) { Spree::Country.by_iso('US') }
  let(:canada) { Spree::Country.by_iso('CA') }

  let(:origin) { create(:stock_location, country: usa) }
  let(:domestic_destination) { create(:address, country: usa) }
  let(:foreign_destination) { create(:address, country: canada, state: nil, state_name: 'Ontario', zipcode: 'K1A 0B1') }

  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let(:variant) { order.line_items.first.variant }

  let(:package) do
    fulfillment = order.fulfillments.first
    fulfillment.to_package.tap { |pkg| pkg.owner = order }
  end

  describe '.international?' do
    it 'is true when origin and destination countries differ' do
      expect(SpreeEasyPost.international?(origin, foreign_destination)).to be true
    end

    it 'is false for a domestic shipment' do
      expect(SpreeEasyPost.international?(origin, domestic_destination)).to be false
    end

    it 'is false when either country is unknown — never guess a customs form' do
      expect(SpreeEasyPost.international?(origin, build(:address, country: nil))).to be false
      expect(SpreeEasyPost.international?(nil, foreign_destination)).to be false
    end
  end

  describe '.customs_info_params' do
    it 'returns nil for a domestic shipment' do
      expect(SpreeEasyPost.customs_info_params(package, origin, domestic_destination)).to be_nil
    end

    it 'builds a declaration for an international shipment' do
      params = SpreeEasyPost.customs_info_params(package, origin, foreign_destination)

      expect(params[:contents_type]).to eq('merchandise')
      expect(params[:customs_certify]).to be true
      expect(params[:customs_items].size).to eq(1)
    end

    it 'carries the variant classification when the merchant recorded it' do
      variant.update!(hs_code: '640411', country_of_origin: 'VN', customs_description: 'Leather footwear')

      item = SpreeEasyPost.customs_info_params(package, origin, foreign_destination)[:customs_items].first

      expect(item[:hs_tariff_number]).to eq('640411')
      expect(item[:origin_country]).to eq('VN')
      expect(item[:description]).to eq('Leather footwear')
    end

    it 'omits classification that was never recorded rather than sending blanks' do
      variant.update!(hs_code: nil, country_of_origin: nil, customs_description: nil)

      item = SpreeEasyPost.customs_info_params(package, origin, foreign_destination)[:customs_items].first

      expect(item).not_to have_key(:hs_tariff_number)
      expect(item).not_to have_key(:origin_country)
      expect(item[:description]).to eq(variant.name)
    end

    it 'takes the signer and contents type from the integration when configured' do
      integration = SpreeEasyPost::Integration.new(
        store: store,
        preferences: { customs_signer: 'Jane Doe', customs_contents_type: 'gift' }
      )

      params = SpreeEasyPost.customs_info_params(package, origin, foreign_destination, integration)

      expect(params[:customs_signer]).to eq('Jane Doe')
      expect(params[:contents_type]).to eq('gift')
    end

    it 'defaults the incoterm to DAP so the recipient is billed for duties' do
      integration = SpreeEasyPost::Integration.new(store: store)

      expect(integration.preferred_incoterm).to eq('DAP')
    end

    it 'rejects an incoterm EasyPost would refuse' do
      integration = SpreeEasyPost::Integration.new(store: store, preferences: { incoterm: 'DDU' })

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_incoterm]).to be_present
    end

    it 'declares the line value and quantity' do
      line_item = order.line_items.first

      item = SpreeEasyPost.customs_info_params(package, origin, foreign_destination)[:customs_items].first

      expect(item[:quantity]).to eq(line_item.quantity)
      expect(item[:value]).to eq((line_item.price.to_f * line_item.quantity).round(2))
    end
  end
end
