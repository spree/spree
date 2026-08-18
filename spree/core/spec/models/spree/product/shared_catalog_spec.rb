require 'spec_helper'

# The product side of the shared catalog: what a product leads with when
# several sellers list it, and the write that used to delete their variants.
# docs/plans/6.0-multi-vendor-marketplace.md, Decision 11.
describe Spree::Product, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:other_seller) { create(:seller, :approved, store: store) }

  describe '#variants= on a master product' do
    let(:product) { create(:product, store: store) }
    let!(:mine) { create(:variant, product: product, seller: seller, sku: 'MINE-1') }
    let!(:theirs) { create(:variant, product: product, seller: other_seller, sku: 'THEIRS-1') }

    # This is the operator's write path, and the operator sees and writes
    # every seller's variants on a master. There is no seller-narrowing here
    # on purpose; a seller's own writes go through the seller branch, which
    # scope-fetches at the controller (Decision 10).
    it 'lets the operator edit and remove any seller\'s variant' do
      product.variants = [{ id: mine.prefixed_id, sku: 'MINE-2' }]

      expect(mine.reload.sku).to eq('MINE-2')
      expect(product.variants.reload).not_to include(theirs)
    end
  end

  describe '#default_variant' do
    let(:product) { create(:product, store: store) }

    it 'prefers the operator\'s own listing over a seller\'s' do
      product.variants.destroy_all
      create(:variant, product: product, seller: seller, sku: 'SELLER-1')
      ours = create(:variant, product: product, sku: 'OURS-1')

      product.reload.send(:set_default_variant)
      product.update_column(:default_variant_id, nil)
      product.send(:set_default_variant)

      expect(product.reload.default_variant).to eq(ours)
    end

    it 'falls back to a seller\'s listing when the operator sells none' do
      product.variants.destroy_all
      theirs = create(:variant, product: product, seller: seller, sku: 'SELLER-1')

      product.update_column(:default_variant_id, nil)
      product.reload.send(:set_default_variant)

      expect(product.reload.default_variant).to eq(theirs)
    end
  end

  describe '#buy_box_variant' do
    let(:product) { create(:product, store: store) }

    before { product.variants.destroy_all }

    it 'leads with the operator\'s own listing over a cheaper seller' do
      create(:variant, product: product, seller: seller, sku: 'S-1', price: 5)
      ours = create(:variant, product: product, sku: 'O-1', price: 9)

      expect(product.reload.buy_box_variant).to eq(ours)
    end

    it 'picks the cheapest among sellers' do
      create(:variant, product: product, seller: seller, sku: 'S-1', price: 20)
      cheap = create(:variant, product: product, seller: other_seller, sku: 'S-2', price: 12)

      expect(product.reload.buy_box_variant).to eq(cheap)
    end

    it 'skips a seller who is suspended' do
      suspended = create(:seller, :suspended, store: store)
      create(:variant, product: product, seller: suspended, sku: 'S-1', price: 5)
      available = create(:variant, product: product, seller: seller, sku: 'S-2', price: 30)

      expect(product.reload.buy_box_variant).to eq(available)
    end

    it 'skips a seller who is away on holiday' do
      away = create(:seller, :on_holiday, store: store)
      create(:variant, product: product, seller: away, sku: 'S-1', price: 5)
      available = create(:variant, product: product, seller: seller, sku: 'S-2', price: 30)

      expect(product.reload.buy_box_variant).to eq(available)
    end

    it 'still names a variant when nothing is buyable, so the page has a price' do
      out_of_stock = create(:variant, product: product, seller: seller, sku: 'S-1', price: 5)
      out_of_stock.stock_items.update_all(count_on_hand: 0, backorderable: false)

      expect(product.reload.buy_box_variant).to eq(out_of_stock)
    end

    it 'answers per option combination, so used and new have their own winners' do
      Spree::Seeds::OptionTypes.call
      condition = Spree::OptionType.find_by!(name: Spree::Seeds::OptionTypes::CONDITION_NAME)
      used = condition.option_values.find_by(name: 'used')
      new_value = condition.option_values.find_by(name: 'new')

      used_variant = create(:variant, product: product, seller: seller, sku: 'U-1', price: 4,
                                      option_values: [used])
      new_variant = create(:variant, product: product, sku: 'N-1', price: 40, option_values: [new_value])

      expect(product.reload.buy_box_variant(option_value_ids: [used.id])).to eq(used_variant)
      expect(product.reload.buy_box_variant(option_value_ids: [new_value.id])).to eq(new_variant)
    end
  end

  describe '#first_available_variant' do
    let(:product) { create(:product, store: store) }

    before { product.variants.destroy_all }

    it 'skips a seller who is not selling today' do
      away = create(:seller, :on_holiday, store: store)
      create(:variant, product: product, seller: away, sku: 'S-1', price: 5)
      available = create(:variant, product: product, seller: seller, sku: 'S-2', price: 30)

      expect(product.reload.first_available_variant('USD')).to eq(available)
    end
  end

  describe 'availability is about the shelf, not the currency' do
    let(:product) { create(:product, store: store) }

    before { product.variants.destroy_all }

    it 'is in stock through a variant priced only in another currency' do
      empty = create(:variant, product: product, sku: 'A-1', price: 10)
      empty.stock_items.update_all(count_on_hand: 0, backorderable: false)
      stocked = create(:variant, product: product, sku: 'B-1', price: nil)
      stocked.prices.destroy_all
      stocked.set_price('EUR', 9)
      stocked.stock_items.update_all(count_on_hand: 5)

      Spree::Current.currency = 'USD'
      expect(product.reload).to be_in_stock
      expect(product).to be_purchasable
    end

    it 'is not purchasable through a suspended seller alone, even when nothing else is priced' do
      suspended = create(:seller, :suspended, store: store)
      create(:variant, product: product, seller: suspended, sku: 'S-1', price: nil)

      expect(product.reload).not_to be_purchasable
      expect(product).not_to be_in_stock
    end
  end

  describe 'rollups follow the buy box' do
    let(:product) { create(:product, store: store) }

    before { product.variants.destroy_all }

    it 'is not purchasable because a suspended seller happens to hold stock' do
      suspended = create(:seller, :suspended, store: store)
      create(:variant, product: product, seller: suspended, sku: 'S-1', price: 5)
      ours = create(:variant, product: product, sku: 'O-1', price: 5)
      ours.stock_items.update_all(count_on_hand: 0, backorderable: false)

      expect(product.reload).not_to be_purchasable
    end
  end
end
