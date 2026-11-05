require 'spec_helper'

RSpec.describe Spree::CollectionRules::Price, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }
  let!(:cheap) { create(:product, store: store, price: 20) }
  let!(:dear) { create(:product, store: store, price: 80) }
  let!(:exact) { create(:product, store: store, price: 50) }

  def rule(**attributes)
    build(:price_collection_rule, collection: collection, **attributes)
  end

  it 'compares base prices in the store default currency, strictly' do
    expect(rule(match_policy: 'less_than').apply(store.products)).to contain_exactly(cheap)
    expect(rule(match_policy: 'greater_than').apply(store.products)).to contain_exactly(dear)
  end

  it 'compares in the rule currency when it names one' do
    allow(store).to receive(:supported_currencies_list).and_return([Money::Currency.find('USD'), Money::Currency.find('EUR')])
    create(:price, variant: dear.default_variant, currency: 'EUR', amount: 10)

    expect(rule(currency: 'eur').apply(store.products)).to contain_exactly(dear)
  end

  it 'ignores price list prices' do
    price_list = create(:price_list, store: store)
    create(:price, variant: dear.default_variant, currency: 'USD', amount: 1, price_list: price_list)

    expect(rule.apply(store.products)).to contain_exactly(cheap)
  end

  it 'requires a decimal amount and a supported currency' do
    expect(rule(value: 'cheap')).not_to be_valid
    expect(rule(currency: 'XYZ')).not_to be_valid
    expect(rule(match_policy: 'is_equal_to')).not_to be_valid
  end
end
