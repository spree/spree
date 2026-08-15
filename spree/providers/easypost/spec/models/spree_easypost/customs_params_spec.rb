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
      expect(params[:customs_items].size).to eq(1)
    end

    # EasyPost requires a signer whenever the declaration is certified, so an
    # integration without one must not certify — or every international quote
    # would fail for the default configuration.
    it 'does not certify the declaration when no signer is configured' do
      params = SpreeEasyPost.customs_info_params(package, origin, foreign_destination)

      expect(params).not_to have_key(:customs_certify)
      expect(params).not_to have_key(:customs_signer)
    end

    it 'certifies the declaration once a signer is named' do
      integration = SpreeEasyPost::Integration.new(store: store, preferences: { customs_signer: 'Jane Doe' })

      params = SpreeEasyPost.customs_info_params(package, origin, foreign_destination, integration)

      expect(params[:customs_certify]).to be true
      expect(params[:customs_signer]).to eq('Jane Doe')
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

    it 'rejects a contents type EasyPost would refuse' do
      integration = SpreeEasyPost::Integration.new(store: store, preferences: { customs_contents_type: 'Merchandise' })

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_customs_contents_type]).to be_present
    end

    # `other` demands a free-text explanation nothing here supplies, so it is
    # deliberately not offered.
    it 'does not offer the contents type that needs an explanation' do
      expect(SpreeEasyPost::Integration::CUSTOMS_CONTENTS_TYPES).not_to include('other')
    end

    it 'declares the line value and quantity' do
      line_item = order.line_items.first

      item = SpreeEasyPost.customs_info_params(package, origin, foreign_destination)[:customs_items].first

      expect(item[:quantity]).to eq(line_item.quantity)
      expect(item[:value]).to eq((line_item.price.to_f * line_item.quantity).round(2))
    end
  end

  describe '.eel_pfc_for' do
    let(:cheap) { [{ value: 100.0, currency: 'USD' }] }
    let(:dear) { [{ value: 3_000.0, currency: 'USD' }] }

    it 'claims the US export exemption for a low-value US-origin shipment' do
      expect(SpreeEasyPost.eel_pfc_for(cheap, origin)).to eq('NOEEI 30.37(a)')
    end

    # Above the filing threshold the merchant owes an export filing of their
    # own; claiming the exemption for them would be a misdeclaration.
    it 'claims nothing above the filing threshold' do
      expect(SpreeEasyPost.eel_pfc_for(dear, origin)).to be_nil
    end

    it 'claims nothing for a non-US origin — the code is a US regulation' do
      german_origin = create(:stock_location, country: Spree::Country.by_iso('DE'))

      expect(SpreeEasyPost.eel_pfc_for(cheap, german_origin)).to be_nil
    end

    # The threshold is a dollar figure; a euro declaration cannot be compared
    # against it without a conversion this code does not attempt.
    it 'claims nothing when the declaration is not in US dollars' do
      in_euros = [{ value: 100.0, currency: 'EUR' }]

      expect(SpreeEasyPost.eel_pfc_for(in_euros, origin)).to be_nil
    end
  end

  describe '.shipment_params' do
    let(:integration) do
      SpreeEasyPost::Integration.new(store: store, preferences: { incoterm: 'DDP', customs_signer: 'Jane Doe' })
    end

    it 'sets no customs form or duty terms on a domestic shipment' do
      params = SpreeEasyPost.shipment_params(package, origin, domestic_destination, integration, store)

      expect(params).not_to have_key(:customs_info)
      expect(params).not_to have_key(:options)
    end

    # The incoterm is a property of the shipment fixed at creation, so it has
    # to ride on the quote — a label bought against that quote cannot add it.
    it 'puts the configured incoterm on an international shipment at creation' do
      params = SpreeEasyPost.shipment_params(package, origin, foreign_destination, integration, store)

      expect(params[:customs_info]).to be_present
      expect(params[:options]).to eq(incoterm: 'DDP')
    end
  end
end
