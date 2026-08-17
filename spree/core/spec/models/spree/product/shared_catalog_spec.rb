require 'spec_helper'

# The product side of the shared catalog: what a product leads with when
# several sellers list it, and the write that used to delete their variants.
# docs/plans/6.0-multi-seller-marketplace.md, Decision 11.
describe Spree::Product, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:other_seller) { create(:seller, :approved, store: store) }

  describe '#variants= ownership filter' do
    let(:product) { create(:product, store: store) }
    let!(:mine) { create(:variant, product: product, seller: seller, sku: 'MINE-1') }
    let!(:theirs) { create(:variant, product: product, seller: other_seller, sku: 'THEIRS-1') }

    it 'keeps another seller\'s variants when the write speaks for one seller' do
      product.writing_seller = seller
      product.variants = [{ id: mine.prefixed_id, sku: 'MINE-2' }]

      expect(product.variants.reload).to include(theirs)
      expect(mine.reload.sku).to eq('MINE-2')
    end

    it 'still removes the writing seller\'s own omitted variants' do
      also_mine = create(:variant, product: product, seller: seller, sku: 'MINE-9')

      product.writing_seller = seller
      product.variants = [{ id: mine.prefixed_id }]

      expect(product.variants.reload).not_to include(also_mine)
      expect(product.variants.reload).to include(mine, theirs)
    end

    it 'removes freely when no seller is named — the operator runs the marketplace' do
      product.variants = [{ id: mine.prefixed_id }]

      expect(product.variants.reload).not_to include(theirs)
    end

    # Editing a rival's row is the same fault as deleting it, through the same
    # payload — an id outside the bound must not resolve at all.
    it 'refuses to edit another seller\'s variant' do
      product.writing_seller = seller

      expect {
        product.variants = [{ id: theirs.prefixed_id, sku: 'STOLEN' }]
      }.to raise_error(ActiveRecord::RecordNotFound)

      expect(theirs.reload.sku).to eq('THEIRS-1')
    end

    it 'bounds a first-party writer to first-party variants' do
      first_party = create(:variant, product: product, sku: 'OURS-1')

      product.writing_seller = nil
      product.variants = [{ id: first_party.prefixed_id }]

      expect(product.variants.reload).to include(mine, theirs, first_party)
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
      condition = Spree::OptionType.condition.first!
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
