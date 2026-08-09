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

  it 'assigns imported products a product type' do
    expect(Spree::Product.where(product_type_id: nil)).to be_empty
  end

  describe 'product types' do
    # The seeds add Default and Digital; the sample data adds one type per family.
    let(:sample_product_types) do
      Spree::ProductType.where.not(name: [
        I18n.t('spree.seed.product_types.default'), I18n.t('spree.seed.product_types.digital')
      ])
    end

    it 'creates one type per product family rather than a single catch-all' do
      expect(sample_product_types.pluck(:name)).to match_array(
        ['Kitchen Appliance', 'Air Treatment', 'Garment Care', 'Vacuum Cleaner', 'Hair Styling', 'Grooming']
      )
    end

    it 'gives every type a custom field schema' do
      sample_product_types.find_each do |product_type|
        expect(product_type.custom_field_definitions).to be_present
        expect(product_type.product_type_custom_field_definitions.required).to be_present
      end
    end

    it 'varies the schema between types' do
      kitchen = Spree::ProductType.find_by(name: 'Kitchen Appliance')
      grooming = Spree::ProductType.find_by(name: 'Grooming')

      expect(kitchen.custom_field_definitions.map(&:key)).to include('capacity')
      expect(grooming.product_type_custom_field_definitions.required.
        map { |join| join.custom_field_definition.key }).to include('runtime')
    end

    it 'seeds the color option type and a category onto every type' do
      sample_product_types.find_each do |product_type|
        expect(product_type.option_types.map(&:name)).to eq(['color'])
        expect(product_type.categories).to be_present
      end
    end

    # A required field with no value in the CSV would block the merchant from
    # re-activating that product in the dashboard.
    it 'backs every required field with a value on every product of the type' do
      incomplete = Spree::Product.includes(:product_type, custom_fields: :custom_field_definition).select do |product|
        next false if product.product_type.nil?

        required_ids = product.product_type.product_type_custom_field_definitions.required.
                       map(&:custom_field_definition_id)
        filled_ids = product.custom_fields.select { |custom_field| custom_field.value.present? }.
                     map(&:custom_field_definition_id)
        (required_ids - filled_ids).any?
      end

      expect(incomplete.map(&:name)).to be_empty
    end

    it 'fills the required fields on the imported products' do
      product = Spree::Product.joins(:product_type).find_by(spree_product_types: { name: 'Kitchen Appliance' })

      expect(product.custom_fields.map { |custom_field| custom_field.custom_field_definition.key }).
        to include('wattage', 'voltage', 'warranty')
    end
  end

  it 'creates variants' do
    expect(Spree::Variant.count).to be > 80
  end

  it 'creates customers' do
    expect(Spree.customer_class.where.not(email: 'spree@example.com').count).to be > 5
  end

  it 'creates completed orders' do
    expect(Spree::Order.complete.count).to be >= 2
  end

  it 'derives payment and fulfillment statuses for the sample orders' do
    statuses = Spree::Order.complete.pluck(:payment_status, :fulfillment_status).flatten
    expect(statuses).to all(be_present)
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
      buyer = Spree.customer_class.find_by(email: 'wholesale@example.com')
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
