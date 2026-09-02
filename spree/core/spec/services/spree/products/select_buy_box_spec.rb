require 'spec_helper'

describe Spree::Products::SelectBuyBox do
  subject(:winner) { described_class.call(product: product.reload, currency: 'USD').value }

  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:other_seller) { create(:seller, :approved, store: store) }
  let(:product) { create(:product, store: store) }

  before { product.variants.destroy_all }

  it 'returns nothing for a product with no variants' do
    expect(winner).to be_nil
  end

  it 'returns the only variant there is' do
    only = create(:variant, product: product, sku: 'O-1', price: 10)

    expect(winner).to eq(only)
  end

  it 'ranks first-party ahead of a cheaper seller' do
    create(:variant, product: product, seller: seller, sku: 'S-1', price: 1)
    ours = create(:variant, product: product, sku: 'O-1', price: 100)

    expect(winner).to eq(ours)
  end

  it 'ranks sellers by price among themselves' do
    create(:variant, product: product, seller: seller, sku: 'S-1', price: 30)
    cheaper = create(:variant, product: product, seller: other_seller, sku: 'S-2', price: 20)

    expect(winner).to eq(cheaper)
  end

  it 'passes over an out-of-stock variant for one that can be bought' do
    empty = create(:variant, product: product, seller: seller, sku: 'S-1', price: 5)
    empty.stock_levels.update_all(count_on_hand: 0, backorderable: false)
    available = create(:variant, product: product, seller: other_seller, sku: 'S-2', price: 50)

    expect(winner).to eq(available)
  end

  it 'passes over a variant with no price in the currency' do
    create(:variant, product: product, seller: seller, sku: 'S-1', price: nil)
    priced = create(:variant, product: product, seller: other_seller, sku: 'S-2', price: 50)

    expect(winner).to eq(priced)
  end

  it 'passes over a seller who is not selling today' do
    [create(:seller, :suspended, store: store), create(:seller, :onboarding, store: store),
     create(:seller, :on_holiday, store: store)].each_with_index do |unavailable, index|
      create(:variant, product: product, seller: unavailable, sku: "X-#{index}", price: 1)
    end
    available = create(:variant, product: product, seller: seller, sku: 'S-9', price: 90)

    expect(winner).to eq(available)
  end

  # The out-of-stock fallback still refuses to lead with a seller who is not
  # selling — otherwise a suspended seller's row could make the product read
  # as purchasable.
  it 'prefers an active seller\'s unbuyable variant over a suspended seller\'s' do
    suspended = create(:seller, :suspended, store: store)
    create(:variant, product: product, seller: suspended, sku: 'X-1', price: 1)
    active_empty = create(:variant, product: product, seller: seller, sku: 'S-1', price: 50)
    active_empty.stock_levels.update_all(count_on_hand: 0, backorderable: false)

    expect(winner).to eq(active_empty)
  end

  it 'still names a variant when nothing at all is buyable' do
    only = create(:variant, product: product, seller: create(:seller, :suspended, store: store), sku: 'S-1', price: 5)

    expect(winner).to eq(only)
  end

  describe 'option combinations' do
    let(:condition) { create(:option_type, name: 'condition', label: 'Condition') }
    let(:used) { create(:option_value, option_type: condition, name: 'used', label: 'Used') }
    let(:new_value) { create(:option_value, option_type: condition, name: 'new', label: 'New') }

    it 'gives each condition its own winner' do
      used_cheap = create(:variant, product: product, seller: seller, sku: 'U-1', price: 4, option_values: [used])
      create(:variant, product: product, seller: other_seller, sku: 'U-2', price: 9, option_values: [used])
      new_one = create(:variant, product: product, sku: 'N-1', price: 40, option_values: [new_value])

      expect(described_class.call(product: product.reload, currency: 'USD', option_value_ids: [used.id]).value).
        to eq(used_cheap)
      expect(described_class.call(product: product.reload, currency: 'USD', option_value_ids: [new_value.id]).value).
        to eq(new_one)
    end

    it 'returns nothing when no variant carries the combination' do
      create(:variant, product: product, sku: 'N-1', price: 40, option_values: [new_value])

      expect(described_class.call(product: product.reload, currency: 'USD', option_value_ids: [used.id]).value).to be_nil
    end
  end

  it 'is swappable' do
    expect(Spree::Dependencies.product_buy_box_service).to eq('Spree::Products::SelectBuyBox')
  end
end
