require 'spec_helper'

describe 'Product scopes', type: :model do
  let!(:product) { create(:product) }

  describe '#available' do
    context 'when discontinued' do
      let!(:discontinued_product) { create(:product, discontinue_on: Time.current - 1.day) }

      it { expect(Spree::Product.available).not_to include(discontinued_product) }
    end

    context 'when not discontinued' do
      let!(:product_2) { create(:product, discontinue_on: Time.current + 1.day) }

      it { expect(Spree::Product.available).to include(product_2) }
    end

    context 'when available' do
      let!(:product_2) { create(:product, available_on: Time.current - 1.day) }

      it { expect(Spree::Product.available).to include(product_2) }
    end

    context 'when not available' do
      let!(:unavailable_product) { create(:product, available_on: Time.current + 1.day) }

      it { expect(Spree::Product.available).not_to include(unavailable_product) }
    end

    context 'different currency' do
      let!(:price_eur) { create(:price, variant: product.master, currency: 'EUR') }
      let!(:product_2) { create(:product) }

      it { expect(Spree::Product.available(nil, 'EUR')).to include(product) }
      it { expect(Spree::Product.available(nil, 'EUR')).not_to include(product_2) }
    end
  end

  describe '.for_filters' do
    subject { Spree::Product.method(:for_filters) }

    let(:taxon_1) { create(:taxon) }
    let(:taxon_2) { create(:taxon) }

    let!(:product_1) { create(:product, currency: 'GBP', taxons: [taxon_1]) }
    let!(:product_2) { create(:product, currency: 'GBP', taxons: [taxon_2]) }

    before do
      create(:product, currency: 'USD', taxons: [create(:taxon)])
    end

    context 'when giving a taxon' do
      it { expect(subject.call('GBP', taxon_1)).to contain_exactly(product_1) }
    end

    context 'when giving no taxon' do
      it { expect(subject.call('GBP')).to contain_exactly(product_1, product_2) }
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

    context 'orders products based on their ordering within the classifications' do
      let(:other_taxon) { create(:taxon, products: [product]) }
      let!(:product_2) { create(:product, taxons: [@child_taxon, other_taxon]) }

      it 'by initial ordering' do
        expect(Spree::Product.in_taxon(@child_taxon)).to eq([product, product_2])
        expect(Spree::Product.in_taxon(other_taxon)).to eq([product, product_2])
      end

      it 'after ordering changed' do
        [@child_taxon, other_taxon].each do |taxon|
          Spree::Classification.find_by(taxon: taxon, product: product).insert_at(2)
          expect(Spree::Product.in_taxon(taxon)).to eq([product_2, product])
        end
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

      let!(:product_2) { create(:product, product_properties: [product_2_property]) }
      let(:product_2_property) { create(:product_property, property: property, value: value_2) }
      let(:value_2) { 'Beta 10%' }

      before do
        create(:product, product_properties: [create(:product_property, property: property, value: '20% Gamma')])
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
    let!(:first_product) { create(:product, name: 'First product') }
    let!(:second_product) { create(:product, name: 'Second product') }
    let!(:third_product) { create(:product, name: 'Other second product') }

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

    let(:child_taxon_1) { create(:taxon, parent: parent_taxon) }
    let(:child_taxon_1_1) { create(:taxon, parent: child_taxon_1) }

    let(:child_taxon_2) { create(:taxon, parent: parent_taxon) }
    let(:child_taxon_2_1) { create(:taxon, parent: child_taxon_2) }

    let!(:product_1) { create(:product) }
    let!(:classification_1_1) { create(:classification, position: 5, product: product_1, taxon: parent_taxon) }
    let!(:classification_1_2) { create(:classification, position: 4, product: product_1, taxon: child_taxon_1_1) }

    let!(:product_2) { create(:product) }
    let!(:classification_2_1) { create(:classification, position: 1, product: product_2, taxon: parent_taxon) }
    let!(:classification_2_2) { create(:classification, position: 2, product: product_2, taxon: child_taxon_2_1) }

    let!(:product_3) { create(:product) }
    let!(:classification_3_1) { create(:classification, position: 3, product: product_3, taxon: child_taxon_1) }
    let!(:classification_3_2) { create(:classification, position: 4, product: product_3, taxon: child_taxon_2_1) }

    let!(:product_4) { create(:product) }
    let!(:classification_4_1) { create(:classification, position: 2, product: product_4, taxon: child_taxon_2) }

    let!(:product_5) { create(:product) }
    let!(:classification_5_1) { create(:classification, position: 1, product: product_5, taxon: child_taxon_1_1) }

    let!(:product_6) { create(:product) }
    let!(:classification_6_1) { create(:classification, position: 6, product: product_6, taxon: child_taxon_2) }
    let!(:classification_6_2) { create(:classification, position: 3, product: product_6, taxon: child_taxon_1) }

    before do
      create_list(:product, 3, taxons: [create(:taxon)])
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
end
