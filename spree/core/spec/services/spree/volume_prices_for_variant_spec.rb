require 'spec_helper'

RSpec.describe Spree::VolumePricesForVariant do
  let(:store) { @default_store }
  let(:variant) { create(:variant, price: 10.00) }
  let(:currency) { 'USD' }

  after do
    Spree::Current.reset
  end

  before do
    Spree::Current.store = store
    Spree::Current.currency = currency
  end

  describe '.call' do
    let!(:low_tier_list) do
      create(:price_list, :active, store: store, name: 'Volume (3-10)', position: 1).tap do |list|
        create(:volume_price_rule, price_list: list, min_quantity: 3, max_quantity: 10)
        create(:price, variant: variant, currency: currency, amount: 8.00, price_list: list)
      end
    end

    let!(:high_tier_list) do
      create(:price_list, :active, store: store, name: 'Volume (11+)', position: 2).tap do |list|
        create(:volume_price_rule, price_list: list, min_quantity: 11, max_quantity: nil)
        create(:price, variant: variant, currency: currency, amount: 6.00, compare_at_amount: 10.00, price_list: list)
      end
    end

    it 'returns tiers sorted by min_quantity with list metadata and prices' do
      tiers = described_class.call(variant: variant)

      expect(tiers.size).to eq(2)
      expect(tiers.map(&:min_quantity)).to eq([3, 11])
      expect(tiers.first.name).to eq('Volume (3-10)')
      expect(tiers.first.max_quantity).to eq(10)
      expect(tiers.first.price.amount).to eq(8.00)
      expect(tiers.second.name).to eq('Volume (11+)')
      expect(tiers.second.max_quantity).to be_nil
      expect(tiers.second.price.amount).to eq(6.00)
      expect(tiers.second.price.compare_at_amount).to eq(10.00)
    end

    it 'reuses cached price lists and rules across variants in the same request' do
      other_variant = create(:variant, price: 10.00, product: variant.product)
      create(:price, variant: other_variant, currency: currency, amount: 8.00, price_list: low_tier_list)
      create(:price, variant: other_variant, currency: currency, amount: 6.00, price_list: high_tier_list)

      described_class.call(variant: variant)
      cached_lists = Spree::Current.price_lists

      described_class.call(variant: other_variant)

      expect(
        Spree::Pricing.price_lists_for(Spree::Pricing::Context.new(currency: currency))
      ).to equal(cached_lists)
    end

    it 'matches Resolver pricing at each tier min quantity' do
      tiers = described_class.call(variant: variant)

      tiers.each do |tier|
        context = Spree::Pricing::Context.new(
          variant: variant,
          currency: currency,
          quantity: tier.min_quantity
        )
        resolved = Spree::Pricing::Resolver.new(context).resolve

        expect(resolved.amount).to eq(tier.price.amount)
        expect(resolved.price_list_id).to eq(tier.price.price_list_id)
      end
    end

    it 'omits lists with blank amounts' do
      create(:price_list, :active, store: store, name: 'Empty tier', position: 3).tap do |list|
        create(:volume_price_rule, price_list: list, min_quantity: 20)
        create(:price, variant: variant, currency: currency, amount: nil, price_list: list)
      end

      tiers = described_class.call(variant: variant)

      expect(tiers.map(&:name)).not_to include('Empty tier')
    end

    it 'respects the current store and currency' do
      other_store = create(:store, default: false, default_currency: 'EUR')
      other_list = create(:price_list, :active, store: other_store, name: 'EUR tier').tap do |list|
        create(:volume_price_rule, price_list: list, min_quantity: 3)
        create(:price, variant: variant, currency: 'EUR', amount: 12.00, price_list: list)
      end

      Spree::Current.reset
      Spree::Current.store = other_store
      Spree::Current.currency = 'EUR'

      tiers = described_class.call(variant: variant)
      expect(tiers.map(&:name)).to eq([other_list.name])
    end

    context 'with a customer group rule' do
      let(:customer_group) { create(:customer_group, store: store) }
      let(:member) { create(:user) }

      let!(:member_tier_list) do
        create(:price_list, :active, store: store, name: 'Wholesale (5+)', position: 0).tap do |list|
          create(:volume_price_rule, price_list: list, min_quantity: 5)
          create(:customer_group_price_rule, price_list: list, customer_group_ids: [customer_group.id])
          create(:price, variant: variant, currency: currency, amount: 5.00, price_list: list)
        end
      end

      before do
        customer_group.add_customers([member.id])
      end

      it 'excludes the list for guests' do
        tiers = described_class.call(variant: variant, user: nil)

        expect(tiers.map(&:name)).not_to include('Wholesale (5+)')
      end

      it 'includes the list for group members' do
        tiers = described_class.call(variant: variant, user: member)

        wholesale = tiers.find { |tier| tier.name == 'Wholesale (5+)' }
        expect(wholesale).to be_present
        expect(wholesale.min_quantity).to eq(5)
        expect(wholesale.price.amount).to eq(5.00)
      end
    end

    context 'with a zone rule on the same price list' do
      let(:eu_zone) { create(:zone, name: 'EU Volume zone') }
      let(:other_zone) { create(:zone, name: 'Other zone') }

      let!(:zone_gated_tier_list) do
        create(:price_list, :active, store: store, name: 'EU Volume (5+)', position: 0).tap do |list|
          create(:volume_price_rule, price_list: list, min_quantity: 5)
          create(:zone_price_rule, price_list: list, zone_ids: [eu_zone.id])
          create(:price, variant: variant, currency: currency, amount: 5.00, price_list: list)
        end
      end

      it 'includes the tier when Spree::Current.zone matches the list zone rule' do
        Spree::Current.zone = eu_zone

        tiers = described_class.call(variant: variant)

        expect(tiers.map(&:name)).to include('EU Volume (5+)')
      end

      it 'excludes the tier when Spree::Current.zone does not match' do
        Spree::Current.zone = other_zone

        tiers = described_class.call(variant: variant)

        expect(tiers.map(&:name)).not_to include('EU Volume (5+)')
      end

      it 'excludes the tier when Spree::Current.zone is unset' do
        Spree::Current.zone = nil

        tiers = described_class.call(variant: variant)

        expect(tiers.map(&:name)).not_to include('EU Volume (5+)')
      end
    end
  end
end
