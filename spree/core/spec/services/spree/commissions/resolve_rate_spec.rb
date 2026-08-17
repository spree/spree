require 'spec_helper'

RSpec.describe Spree::Commissions::ResolveRate do
  let(:store) { @default_store }
  let(:vendor) { create(:vendor, :approved, store: store) }
  let(:other_vendor) { create(:vendor, :approved, store: store) }
  let(:product) { create(:product, store: store, vendor: vendor) }
  let(:order) { create(:order, store: store, currency: 'USD') }
  let(:line_item) { create(:line_item, order: order, variant: product.default_variant) }

  def resolve(currency: 'USD')
    described_class.call(line_item: line_item, vendor: vendor, store: store, currency: currency).value
  end

  it 'returns nothing when the marketplace has configured no rates' do
    expect(resolve).to be_nil
  end

  it 'takes an untargeted rate as the marketplace default' do
    rate = create(:commission_rate, store: store)

    expect(resolve).to eq(rate)
  end

  it 'ignores a disabled rate' do
    create(:commission_rate, :disabled, store: store)

    expect(resolve).to be_nil
  end

  it 'ignores another store rates' do
    create(:commission_rate, store: create(:store))

    expect(resolve).to be_nil
  end

  # Precedence is the operator's own ordering, not a hardcoded ladder.
  it 'takes the first match in list order' do
    later = create(:commission_rate, store: store)
    winner = create(:commission_rate, store: store) # created last, so top of list

    expect(described_class.candidates_for(store)).to eq([winner, later])
    expect(resolve).to eq(winner)
  end

  it 'skips a higher-placed rate whose targeting does not match' do
    fallback = create(:commission_rate, store: store)
    mismatched = create(:commission_rate, store: store)
    create(:commission_vendor_rule, commission_rate: mismatched, vendors: [other_vendor])

    expect(resolve).to eq(fallback)
  end

  # Which rule type a rate names decides nothing — a vendor-targeted rate
  # placed above a product-targeted one wins, and that is the point of making
  # the order editable rather than inferring specificity.
  it 'lets the operator order beat any notion of how specific a rule is' do
    product_rate = create(:commission_rate, store: store)
    create(:commission_product_rule, commission_rate: product_rate, products: [product])
    vendor_rate = create(:commission_rate, store: store)
    create(:commission_vendor_rule, commission_rate: vendor_rate, vendors: [vendor])

    expect(resolve).to eq(vendor_rate)

    product_rate.move_to_top

    expect(resolve).to eq(product_rate)
  end

  # A rate with no rules matches everything, so anything under it is
  # unreachable. It belongs at the bottom, and the seed puts it there.
  it 'lets an untargeted rate shadow everything below it' do
    targeted = create(:commission_rate, store: store)
    create(:commission_product_rule, commission_rate: targeted, products: [product])
    catch_all = create(:commission_rate, store: store) # top of list

    expect(resolve).to eq(catch_all)

    catch_all.move_to_bottom

    expect(resolve).to eq(targeted)
  end

  it 'matches a rate targeting the seller' do
    rate = create(:commission_rate, store: store)
    create(:commission_vendor_rule, commission_rate: rate, vendors: [vendor])

    expect(resolve).to eq(rate)
  end

  it 'matches a rate targeting the product' do
    rate = create(:commission_rate, store: store)
    create(:commission_product_rule, commission_rate: rate, products: [product])

    expect(resolve).to eq(rate)
  end

  it 'matches a rate targeting the product category' do
    category = create(:category)
    product.categories << category
    rate = create(:commission_rate, store: store)
    create(:commission_category_rule, commission_rate: rate, categories: [category])

    expect(resolve).to eq(rate)
  end

  # A rate on a parent category governs everything filed beneath it, so a
  # marketplace does not have to restate the rule on every new leaf.
  it 'matches a rate targeting an ancestor of the product category' do
    parent = create(:category)
    child = create(:category, parent: parent, taxonomy: parent.taxonomy)
    product.categories << child
    rate = create(:commission_rate, store: store)
    create(:commission_category_rule, commission_rate: rate, categories: [parent])

    expect(resolve).to eq(rate)
  end

  # Walking a nested set is a query per category, so the ancestors are resolved
  # for the whole order at once. That batching has to give exactly what asking
  # each category on its own would.
  describe '.categories_for' do
    it 'gives each product its categories and their ancestors' do
      root = create(:category)
      middle = create(:category, parent: root, taxonomy: root.taxonomy)
      leaf = create(:category, parent: middle, taxonomy: root.taxonomy)
      unrelated = create(:category)

      deep = create(:product, store: store)
      deep.categories << leaf
      wide = create(:product, store: store)
      wide.categories << unrelated
      wide.categories << middle

      resolved = described_class.categories_for([deep, wide])

      [deep, wide].each do |product|
        one_at_a_time = product.categories.flat_map { |c| c.self_and_ancestors.to_a }.uniq

        expect(resolved[product.id].map(&:id)).to match_array(one_at_a_time.map(&:id))
      end
    end

    it 'gives a product with no categories an empty list' do
      bare = create(:product, store: store)

      expect(described_class.categories_for([bare])).to eq(bare.id => [])
    end

    it 'resolves nothing for nothing' do
      expect(described_class.categories_for([])).to eq({})
    end

    # Nested-set bounds only mean something inside the tree that assigned them,
    # so another store's category can enclose this one by coincidence. Letting
    # it through would make a rate targeting that category match a sale in a
    # different store entirely.
    it 'never reaches into another store tree' do
      other_store = create(:store)

      root = create(:category, store: store)
      leaf = create(:category, parent: root, taxonomy: root.taxonomy, store: store)

      # Deep enough that its root's bounds enclose the other store's leaf.
      foreign_root = create(:category, store: other_store)
      foreign_branch = create(:category, parent: foreign_root, taxonomy: foreign_root.taxonomy, store: other_store)
      create(:category, parent: foreign_branch, taxonomy: foreign_root.taxonomy, store: other_store)
      foreign_leaf = create(:category, parent: foreign_root, taxonomy: foreign_root.taxonomy, store: other_store)

      mine = create(:product, store: store)
      mine.categories << leaf
      theirs = create(:product, store: other_store)
      theirs.categories << foreign_leaf

      # Both stores in one call is what fills the pool with foreign rows.
      resolved = described_class.categories_for([mine, theirs])

      expect(resolved[mine.id].map(&:store_id).uniq).to eq([store.id])
      expect(resolved[theirs.id].map(&:store_id).uniq).to eq([other_store.id])
    end
  end

  describe 'currency' do
    it 'passes over a fixed rate priced in another currency' do
      fallback = create(:commission_rate, store: store)
      # Top of the list, but states no dollar amount — so a dollar sale falls
      # past it rather than being charged a euro figure.
      create(:commission_rate, :fixed, store: store, amounts: { 'EUR' => 3 })

      expect(resolve(currency: 'USD')).to eq(fallback)
    end

    it 'accepts a percentage rate in any currency' do
      rate = create(:commission_rate, store: store, kind: 'percentage')

      expect(resolve(currency: 'EUR')).to eq(rate)
    end
  end
end
