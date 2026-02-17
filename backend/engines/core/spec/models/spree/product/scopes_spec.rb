require 'spec_helper'

describe 'Product scopes', type: :model do
  let(:store) { @default_store }
  let!(:product) { create(:product, stores: [store]) }

  describe '#available' do
    context 'when discontinued' do
      let!(:discontinued_product) { create(:product, status: 'archived', stores:[store]) }

      it { expect(Spree::Product.available).not_to include(discontinued_product) }
    end

    context 'when not discontinued' do
      let!(:product_2) { create(:product, discontinue_on: Time.current + 1.day, stores: [store]) }

      it { expect(Spree::Product.available).to include(product_2) }
    end

    context 'when available' do
      let!(:product_2) { create(:product, status: 'active', stores: [store]) }

      it { expect(Spree::Product.available).to include(product_2) }
    end

    context 'when not available' do
      let!(:unavailable_product) { create(:product, status: 'draft', stores: [store]) }

      it { expect(Spree::Product.available).not_to include(unavailable_product) }
    end

    context 'different currency' do
      let!(:price_eur) { create(:price, variant: product.master, currency: 'EUR') }
      let!(:product_2) { create(:product, stores: [store]) }

      it { expect(Spree::Product.available(nil, 'EUR')).to include(product) }
      it { expect(Spree::Product.available(nil, 'EUR')).not_to include(product_2) }
    end
  end

  describe '.for_filters' do
    subject { Spree::Product.method(:for_filters) }

    let(:taxon_1) { create(:taxon) }
    let(:taxon_2) { create(:taxon) }

    let!(:product_1) { create(:product, currency: 'GBP', taxons: [taxon_1], stores: [store]) }
    let!(:product_2) { create(:product, currency: 'GBP', taxons: [taxon_2], stores: [store]) }

    before do
      create(:product, currency: 'USD', taxons: [create(:taxon)], stores: [store])
    end

    context 'when giving a taxon' do
      it { expect(subject.call('GBP', taxon: taxon_1)).to contain_exactly(product_1) }
    end

    context 'when giving a currency with no products' do
      it { expect(subject.call('PLN')).to be_empty }
    end
  end

  context 'A product assigned to parent and child taxons' do
    before do
      @taxonomy = create(:taxonomy)
      @root_taxon = @taxonomy.root

      @parent_taxon = create(:taxon, name: 'Parent', taxonomy_id: @taxonomy.id, parent: @root_taxon)
      @child_taxon = create(:taxon, name: 'Child 1', taxonomy_id: @taxonomy.id, parent: @parent_taxon)
      @parent_taxon.reload # Need to reload for descendents to show up

      product.taxons << @parent_taxon
      product.taxons << @child_taxon
    end

    it 'calling Product.in_taxon returns products in child taxons' do
      product.taxons -= [@child_taxon]
      expect(product.taxons.count).to eq(1)

      expect(Spree::Product.in_taxon(@parent_taxon)).to include(product)
    end

    it 'calling Product.in_taxon should not return duplicate records' do
      expect(Spree::Product.in_taxon(@parent_taxon).to_a.size).to eq(1)
    end

    context 'returns correct products for taxon' do
      let(:other_taxon) { create(:taxon, products: [product]) }
      let!(:product_2) { create(:product, taxons: [@child_taxon, other_taxon], stores: [store]) }

      it 'includes all products in the taxon' do
        expect(Spree::Product.in_taxon(@child_taxon)).to include(product, product_2)
        expect(Spree::Product.in_taxon(other_taxon)).to include(product, product_2)
      end
    end
  end

  context 'property scopes' do
    let(:name) { property.name }
    let(:value) { 'Alpha' }

    let(:product_property) { create(:product_property, property: property, value: value) }
    let(:property) { create(:property, :brand) }

    before do
      product.product_properties << product_property
    end

    context 'with_property' do
      subject(:with_property) { Spree::Product.method(:with_property) }

      it "finds by a property's name" do
        expect(with_property.call(name).count).to eq(1)
      end

      it "doesn't find any properties with an unknown name" do
        expect(with_property.call('fake').count).to eq(0)
      end

      it 'finds by a property' do
        expect(with_property.call(property).count).to eq(1)
      end

      it 'finds by an id' do
        expect(with_property.call(property.id).count).to eq(1)
      end

      it 'cannot find a property with an unknown id' do
        expect(with_property.call(0).count).to eq(0)
      end
    end

    context 'with_property_value' do
      subject(:with_property_value) { Spree::Product.method(:with_property_value) }

      it "finds by a property's name" do
        expect(with_property_value.call(name, value).count).to eq(1)
      end

      it "cannot find by an unknown property's name" do
        expect(with_property_value.call('fake', value).count).to eq(0)
      end

      it 'cannot find with a name by an incorrect value' do
        expect(with_property_value.call(name, 'fake').count).to eq(0)
      end

      it 'finds by a property' do
        expect(with_property_value.call(property, value).count).to eq(1)
      end

      it 'cannot find with a property by an incorrect value' do
        expect(with_property_value.call(property, 'fake').count).to eq(0)
      end

      it 'finds by an id with a value' do
        expect(with_property_value.call(property.id, value).count).to eq(1)
      end

      it 'cannot find with an invalid id' do
        expect(with_property_value.call(0, value).count).to eq(0)
      end

      it 'cannot find with an invalid value' do
        expect(with_property_value.call(property.id, 'fake').count).to eq(0)
      end
    end

    context 'with_property_values' do
      subject(:with_property_values) { Spree::Product.method(:with_property_values) }

      let!(:product_2) { create(:product, product_properties: [product_2_property], stores: [store]) }
      let(:product_2_property) { create(:product_property, property: property, value: value_2) }
      let(:value_2) { 'Beta 10%' }

      before do
        create(:product, product_properties: [create(:product_property, property: property, value: '20% Gamma')], stores: [store])
      end

      it 'finds by property values' do
        expect(with_property_values.call(name, [value, value_2, 'non_existent'])).to contain_exactly(
          product, product_2
        )
      end

      it 'cannot find with an invalid property name' do
        expect(with_property_values.call('fake', [value, value_2])).to be_empty
      end

      it 'cannot find with invalid property values' do
        expect(with_property_values.call(name, ['fake'])).to be_empty
      end
    end
  end

  context '#add_simple_scopes' do
    let(:simple_scopes) { [:ascend_by_updated_at, :descend_by_name] }

    before do
      Spree::Product.add_simple_scopes(simple_scopes)
    end

    context 'define scope' do
      context 'ascend_by_updated_at' do
        context 'on class' do
          it { expect(Spree::Product.ascend_by_updated_at.to_sql).to eq Spree::Product.order(Arel.sql("#{Spree::Product.quoted_table_name}.updated_at ASC")).to_sql }
        end

        context 'on ActiveRecord::Relation' do
          it { expect(Spree::Product.limit(2).ascend_by_updated_at.to_sql).to eq Spree::Product.limit(2).order(Arel.sql("#{Spree::Product.quoted_table_name}.updated_at ASC")).to_sql }
          it { expect(Spree::Product.limit(2).ascend_by_updated_at.to_sql).to eq Spree::Product.ascend_by_updated_at.limit(2).to_sql }
        end
      end

      context 'descend_by_name' do
        context 'on class' do
          it { expect(Spree::Product.descend_by_name.to_sql).to eq Spree::Product.order(Arel.sql("#{Spree::Product.quoted_table_name}.name DESC")).to_sql }
        end

        context 'on ActiveRecord::Relation' do
          it { expect(Spree::Product.limit(2).descend_by_name.to_sql).to eq Spree::Product.limit(2).order(Arel.sql("#{Spree::Product.quoted_table_name}.name DESC")).to_sql }
          it { expect(Spree::Product.limit(2).descend_by_name.to_sql).to eq Spree::Product.descend_by_name.limit(2).to_sql }
        end
      end
    end
  end

  context '#search_by_name' do
    let!(:first_product) { create(:product, name: 'First product', stores: [store]) }
    let!(:second_product) { create(:product, name: 'Second product',stores: [store]) }
    let!(:third_product) { create(:product, name: 'Other second product',stores: [store]) }

    it 'shows product whose name contains phrase' do
      result = Spree::Product.search_by_name('First').to_a
      expect(result).to include(first_product)
      expect(result.count).to eq(1)
    end

    it 'shows multiple products whose names contain phrase' do
      result = Spree::Product.search_by_name('product').to_a
      expect(result).to include(product, first_product, second_product, third_product)
      expect(result.count).to eq(4)
    end

    it 'is case insensitive for search phrases' do
      result = Spree::Product.search_by_name('Second').to_a
      expect(result).to include(second_product, third_product)
      expect(result.count).to eq(2)
    end
  end

  context '#ascend_by_taxons_min_position' do
    subject(:ordered_products) { Spree::Product.ascend_by_taxons_min_position(taxons) }

    let(:taxons) { [parent_taxon, child_taxon_1, child_taxon_2, child_taxon_1_1, child_taxon_2_1] }

    let(:parent_taxon) { create(:taxon) }

    let(:child_taxon_1) { create(:taxon, parent: parent_taxon, taxonomy: parent_taxon.taxonomy) }
    let(:child_taxon_1_1) { create(:taxon, parent: child_taxon_1, taxonomy: child_taxon_1.taxonomy) }

    let(:child_taxon_2) { create(:taxon, parent: parent_taxon, taxonomy: parent_taxon.taxonomy) }
    let(:child_taxon_2_1) { create(:taxon, parent: child_taxon_2,taxonomy: child_taxon_2.taxonomy) }

    let!(:product_1) { create(:product, stores: [store]) }
    let!(:classification_1_1) { create(:classification, position: 5, product: product_1, taxon: parent_taxon) }
    let!(:classification_1_2) { create(:classification, position: 4, product: product_1, taxon: child_taxon_1_1) }

    let!(:product_2) { create(:product, stores: [store]) }
    let!(:classification_2_1) { create(:classification, position: 1, product: product_2, taxon: parent_taxon) }
    let!(:classification_2_2) { create(:classification, position: 2, product: product_2, taxon: child_taxon_2_1) }

    let!(:product_3) { create(:product, stores: [store]) }
    let!(:classification_3_1) { create(:classification, position: 3, product: product_3, taxon: child_taxon_1) }
    let!(:classification_3_2) { create(:classification, position: 4, product: product_3, taxon: child_taxon_2_1) }

    let!(:product_4) { create(:product, stores: [store]) }
    let!(:classification_4_1) { create(:classification, position: 2, product: product_4, taxon: child_taxon_2) }

    let!(:product_5) { create(:product, stores: [store]) }
    let!(:classification_5_1) { create(:classification, position: 1, product: product_5, taxon: child_taxon_1_1) }

    let!(:product_6) { create(:product, stores: [store]) }
    let!(:classification_6_1) { create(:classification, position: 6, product: product_6, taxon: child_taxon_2) }
    let!(:classification_6_2) { create(:classification, position: 3, product: product_6, taxon: child_taxon_1) }

    before do
      create_list(:product, 3, taxons: [create(:taxon)], stores: [store])
    end

    it 'orders products by ascending taxons minimum position' do
      expect(ordered_products).to eq(
        [
          product_2, product_5, # position: 1
          product_4,            # position: 2
          product_6, product_3, # position: 3
          product_1             # position: 4
        ]
      )
    end
  end

  describe '#for_store' do
    subject(:products_by_store) { Spree::Product.for_store(store) }
    let(:another_store) { create(:store) }

    before do
      create_list(:product, 3, stores: [another_store])
    end

    it 'returns products assigned to a store' do
      expect(products_by_store).to contain_exactly(product)
    end
  end

  # Regression test for SD-1439 ambiguous column name: count_on_hand
  describe '#in_stock.in_stock_or_backorderable' do
    it do
      expect { Spree::Product.in_stock.in_stock_or_backorderable.count }.not_to raise_error
    end
  end

  describe '.by_best_selling' do
    let!(:product_1) { create(:product, name: 'Product 1', stores: [store]) }
    let!(:product_2) { create(:product, name: 'Product 2', stores: [store]) }
    let!(:product_3) { create(:product, name: 'Product 3', stores: [store]) }
    let!(:product_4) { create(:product, name: 'Product 4', stores: [store]) }
    let(:test_product_ids) { [product_1.id, product_2.id, product_3.id, product_4.id] }

    def refresh_all_metrics!
      [product_1, product_2, product_3, product_4].each do |p|
        p.store_products.find_by(store: store)&.refresh_metrics!
      end
    end

    context 'with completed orders' do
      before do
        # Product 2: 3 units sold (3 orders x 1 quantity each)
        create_list(:completed_order_with_totals, 3, line_items_price: 100, store: store, variants: [product_2.master])

        # Product 1: 2 units sold (2 orders x 1 quantity each)
        create_list(:completed_order_with_totals, 2, line_items_price: 100, store: store, variants: [product_1.master])

        # Product 3: 1 unit sold (1 order x 1 quantity)
        create(:completed_order_with_totals, line_items_price: 150, store: store, variants: [product_3.master])

        # Product 4: no completed orders

        refresh_all_metrics!
      end

      it 'orders products by units_sold_count in descending order by default' do
        products = Spree::Product.where(id: test_product_ids).by_best_selling
        expect(products.map(&:name)).to eq(['Product 2', 'Product 1', 'Product 3', 'Product 4'])
      end

      it 'orders products by units_sold_count in ascending order when specified' do
        products = Spree::Product.where(id: test_product_ids).by_best_selling(:asc)
        expect(products.map(&:name)).to eq(['Product 4', 'Product 3', 'Product 1', 'Product 2'])
      end
    end

    context 'with incomplete orders' do
      before do
        # Product 1: 2 units sold (2 completed orders)
        create_list(:completed_order_with_totals, 2, line_items_price: 100, store: store, variants: [product_1.master])

        # Product 2: 1 unit sold (1 completed order) + 2 incomplete orders (should not be counted)
        create(:completed_order_with_totals, line_items_price: 100, store: store, variants: [product_2.master])
        create_list(:order_with_totals, 2, line_items_price: 100, store: store, variants: [product_2.master])

        refresh_all_metrics!
      end

      it 'only counts units from completed orders' do
        products = Spree::Product.where(id: test_product_ids).by_best_selling
        expect(products.first.name).to eq('Product 1')

        product_1_store_product = product_1.store_products.find_by(store: store)
        product_2_store_product = product_2.store_products.find_by(store: store)

        expect(product_1_store_product.units_sold_count).to eq(2)
        expect(product_2_store_product.units_sold_count).to eq(1)
      end
    end

    context 'when products have same units_sold_count' do
      before do
        # Both products have 2 units sold, but different revenue
        # Product 1: 2 units, lower revenue
        create_list(:completed_order_with_totals, 2, line_items_price: 100, store: store, variants: [product_1.master])

        # Product 2: 2 units, higher revenue
        create_list(:completed_order_with_totals, 2, line_items_price: 150, store: store, variants: [product_2.master])

        refresh_all_metrics!
      end

      it 'uses revenue as secondary sort criteria' do
        products = Spree::Product.where(id: test_product_ids).by_best_selling
        # Both have 2 units sold, but product_2 has higher revenue
        expect(products.first.name).to eq('Product 2')
        expect(products.second.name).to eq('Product 1')

        product_1_store_product = product_1.store_products.find_by(store: store)
        product_2_store_product = product_2.store_products.find_by(store: store)

        expect(product_2_store_product.revenue).to be > product_1_store_product.revenue
      end
    end

    context 'with varying quantities' do
      before do
        # Product 1: 5 units sold (quantity 2 + quantity 3)
        order1 = create(:order_with_line_items, line_items_count: 0, store: store)
        create(:line_item, order: order1, variant: product_1.master, price: 50, quantity: 2)
        create(:line_item, order: order1, variant: product_1.master, price: 50, quantity: 3)
        order1.update!(completed_at: Time.current)

        # Product 2: 2 units sold (quantity 2)
        order2 = create(:order_with_line_items, line_items_count: 0, store: store)
        create(:line_item, order: order2, variant: product_2.master, price: 100, quantity: 2)
        order2.update!(completed_at: Time.current)

        refresh_all_metrics!
      end

      it 'sums line item quantities for units_sold_count' do
        products = Spree::Product.where(id: test_product_ids).by_best_selling

        product_1_store_product = product_1.store_products.find_by(store: store)
        product_2_store_product = product_2.store_products.find_by(store: store)

        # Product 1: 2 + 3 = 5 units
        expect(product_1_store_product.units_sold_count).to eq(5)
        # Product 2: 2 units
        expect(product_2_store_product.units_sold_count).to eq(2)

        # Product 1 should be ranked higher due to more units sold
        expect(products.first.name).to eq('Product 1')
      end
    end

    context 'with multiple orders containing multiple line items' do
      before do
        # Product 1: 5 units sold across 2 orders (quantity 3 + quantity 2)
        order1 = create(:order_with_line_items, line_items_count: 0, store: store)
        create(:line_item, order: order1, variant: product_1.master, price: 50, quantity: 3)
        order1.update!(completed_at: Time.current)

        order2 = create(:order_with_line_items, line_items_count: 0, store: store)
        create(:line_item, order: order2, variant: product_1.master, price: 50, quantity: 2)
        order2.update!(completed_at: Time.current)

        # Product 2: 4 units sold in 1 order (quantity 4)
        order3 = create(:order_with_line_items, line_items_count: 0, store: store)
        create(:line_item, order: order3, variant: product_2.master, price: 100, quantity: 4)
        order3.update!(completed_at: Time.current)

        refresh_all_metrics!
      end

      it 'ranks by total units sold across all orders' do
        products = Spree::Product.where(id: test_product_ids).by_best_selling

        product_1_store_product = product_1.store_products.find_by(store: store)
        product_2_store_product = product_2.store_products.find_by(store: store)

        # Product 1: 3 + 2 = 5 units sold
        expect(product_1_store_product.units_sold_count).to eq(5)
        # Product 2: 4 units sold
        expect(product_2_store_product.units_sold_count).to eq(4)

        # Product 1 should rank first because it has more units sold (5 vs 4)
        expect(products.first.name).to eq('Product 1')
        expect(products.second.name).to eq('Product 2')
      end
    end

    context 'with products having no orders' do
      before do
        refresh_all_metrics!
      end

      it 'includes products with no orders at the end' do
        products = Spree::Product.where(id: test_product_ids).by_best_selling
        expect(products.length).to eq(4)
        # All products should be included, those without orders have units_sold_count = 0
        [product_1, product_2, product_3, product_4].each do |p|
          store_product = p.store_products.find_by(store: store)
          expect(store_product.units_sold_count).to eq(0)
          expect(store_product.revenue).to eq(0)
        end
      end
    end

    context 'with products having only pending orders (no completed_at)' do
      before do
        # Product 1: 2 units sold (2 completed orders)
        create_list(:completed_order_with_totals, 2, line_items_price: 100, store: store, variants: [product_1.master])

        # Product 2: 1 pending order (no completed_at) - should not be counted
        create(:order_with_line_items, line_items_count: 1, store: store, variants: [product_2.master])

        # Product 3: 2 pending orders (not counted) + 1 completed order (1 unit)
        create_list(:order_with_line_items, 2, line_items_count: 1, store: store, variants: [product_3.master])
        create(:completed_order_with_totals, line_items_price: 100, store: store, variants: [product_3.master])

        # Product 4: no orders at all

        refresh_all_metrics!
      end

      it 'includes products with only pending orders with units_sold_count = 0' do
        products = Spree::Product.where(id: test_product_ids).by_best_selling

        # All products should be included
        expect(products.length).to eq(4)

        product_1_sp = product_1.store_products.find_by(store: store)
        product_2_sp = product_2.store_products.find_by(store: store)
        product_3_sp = product_3.store_products.find_by(store: store)
        product_4_sp = product_4.store_products.find_by(store: store)

        # Product 2 has pending orders but no completed orders - count should be 0
        expect(product_2_sp.units_sold_count).to eq(0)
        expect(product_2_sp.revenue).to eq(0)

        # Product 1 has 2 units sold (2 completed orders with quantity 1 each)
        expect(product_1_sp.units_sold_count).to eq(2)

        # Product 3 has 1 unit sold (1 completed order, pending orders not counted)
        expect(product_3_sp.units_sold_count).to eq(1)

        # Product 4 has no orders at all - count should be 0
        expect(product_4_sp.units_sold_count).to eq(0)
        expect(product_4_sp.revenue).to eq(0)
      end

      it 'orders products correctly with pending orders included' do
        products = Spree::Product.where(id: test_product_ids).by_best_selling
        # Product 1: 2 units sold (first)
        # Product 3: 1 unit sold (second)
        # Product 2 & 4: 0 units sold (last, order between them is non-deterministic)
        expect(products.first(2).map(&:name)).to eq(['Product 1', 'Product 3'])
        expect(products.last(2).map(&:name)).to contain_exactly('Product 2', 'Product 4')
      end
    end
  end

  context 'options scopes' do
    let(:option_type) { create(:option_type) }
    let(:option_value) { create(:option_value, option_type: option_type) }
    let!(:product) { create(:product, option_types: [option_type]) }
    let!(:variant) { create(:variant, product: product, option_values: [option_value]) }

    describe '.with_option' do
      subject(:with_option) { Spree::Product.method(:with_option) }

      it "finds by a option type's name" do
        expect(with_option.call(option_type.name).count).to eq(1)
      end

      it "doesn't find any option types with an unknown name" do
        expect(with_option.call('fake').count).to eq(0)
      end

      it 'finds by a option type' do
        expect(with_option.call(option_type).count).to eq(1)
      end

      it 'finds by an id' do
        expect(with_option.call(option_type.id).count).to eq(1)
      end

      it 'cannot find an option type with an unknown id' do
        expect(with_option.call(0).count).to eq(0)
      end
    end

    describe '.with_option_value' do
      subject(:with_option) { Spree::Product.method(:with_option_value) }

      it "finds by a option type's name" do
        expect(with_option.call(option_type.name, option_value.name).count).to eq({ product.id => 1 })
      end

      it "doesn't find any option types with an unknown name" do
        expect(with_option.call('fake', 'fake').count).to eq({})
      end

      it 'finds by a option type' do
        expect(with_option.call(option_type, option_value.name).count).to eq({ product.id => 1 })
      end

      it 'finds by an id' do
        expect(with_option.call(option_type.id, option_value.name).count).to eq({ product.id => 1 })
      end

      it 'cannot find an option type with an unknown id' do
        expect(with_option.call(0, 'fake').count).to eq({})
      end

      it 'can return product ids' do
        expect(with_option.call(option_type, option_value.name).ids).to match_array([product.id])
      end
    end
  end
end
