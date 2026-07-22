require 'spec_helper'

RSpec.describe Spree::SampleData::Loader, type: :service, without_global_store: true do
  before(:all) do
    DatabaseCleaner.clean_with(:truncation)
    described_class.call
  end

  after(:all) do
    DatabaseCleaner.clean_with(:truncation)
  end

  it 'creates products' do
    expect(Spree::Product.count).to be > 30
  end

  it 'creates variants' do
    expect(Spree::Variant.count).to be > 100
  end

  it 'creates customers' do
    expect(Spree.user_class.where.not(email: 'spree@example.com').count).to be > 5
  end

  it 'creates completed orders' do
    expect(Spree::Order.complete.count).to be >= 2
  end

  describe 'wholesale demo data' do
    let(:store) { Spree::Store.default }
    let(:wholesale) { store.channels.find_by(code: 'wholesale') }

    it 'gates the wholesale channel' do
      expect(wholesale.resolved_storefront_access).to eq('login_required')
      expect(wholesale.resolved_guest_checkout).to be false
    end

    it 'publishes the catalog to the wholesale channel' do
      expect(wholesale.products.count).to be > 30
    end

    it 'creates an approved wholesale buyer' do
      buyer = Spree.user_class.find_by(email: 'wholesale@example.com')
      group = store.customer_groups.find_by(name: 'Wholesale')

      expect(buyer).to be_present
      expect(group.customers).to include(buyer)
    end

    it 'creates an active wholesale price list keyed to the group with a case-pack minimum' do
      price_list = store.price_lists.find_by(name: 'Wholesale')

      expect(price_list.status).to eq('active')
      expect(price_list.price_rules.map(&:class)).to include(
        Spree::PriceRules::CustomerGroupRule,
        Spree::PriceRules::VolumeRule
      )
      expect(price_list.match_policy).to eq('all')
      expect(price_list.prices.count).to be > 50

      volume_rule = price_list.price_rules.find { |rule| rule.is_a?(Spree::PriceRules::VolumeRule) }
      expect(volume_rule.preferred_min_quantity).to eq(10)
    end

    it 'seeds wholesale prices for every supported currency' do
      price_list = store.price_lists.find_by(name: 'Wholesale')
      supported = store.supported_currencies_list.map(&:iso_code)
      eligible_variant_ids = Spree::Variant.eligible.where(product_id: store.product_ids).pluck(:id)

      supported.each do |currency|
        expect(price_list.prices.where(currency: currency).pluck(:variant_id)).to match_array(eligible_variant_ids)
      end

      wholesale_price = price_list.prices.where(currency: 'EUR').where.not(amount: nil).first
      expect(wholesale_price).to be_present

      base_price = Spree::Price.find_by(price_list_id: nil, variant_id: wholesale_price.variant_id, currency: 'EUR')
      expect(wholesale_price.amount).to eq((base_price.amount * 0.6).round(2))
    end

    it 'mints a wholesale-bound publishable key' do
      expect(store.api_keys.active.publishable.where(channel: wholesale)).to exist
    end
  end
end
