require 'spec_helper'

module Spree
  describe Classification, type: :model do
    let(:store) { @default_store }

    # Regression test for #3494
    let(:taxon_with_5_products) do
      products = []
      5.times do
        products << create(:base_product)
      end

      create(:category, products: products)
    end

    it 'cannot link the same category to the same product more than once' do
      product = create(:product)
      category = create(:category)
      expect { product.categories << category }.not_to raise_error
      expect { product.categories << category }.to raise_error(ActiveRecord::RecordInvalid)
    end

    def positions_to_be_valid(category)
      positions = category.reload.classifications.map(&:position)
      expect(positions).to eq((1..category.classifications.count).to_a)
    end

    it 'has a valid fixtures' do
      expect positions_to_be_valid(taxon_with_5_products)
      expect(Spree::ProductCategory.count).to eq 5
    end

    context 'removing product from category' do
      before do
        p = taxon_with_5_products.products[1]
        expect(p.classifications.first.position).to eq(2)
        taxon_with_5_products.products.destroy(p)
      end

      it 'resets positions' do
        expect positions_to_be_valid(taxon_with_5_products)
      end
    end

    context "replacing category's products" do
      before do
        products = taxon_with_5_products.products.to_a
        products.pop(1)
        taxon_with_5_products.products = products
        taxon_with_5_products.save!
      end

      it 'resets positions' do
        expect positions_to_be_valid(taxon_with_5_products)
      end
    end

    context 'removing category from product' do
      before do
        p = taxon_with_5_products.products[1]
        p.taxons.destroy(taxon_with_5_products)
        p.save!
      end

      it 'resets positions' do
        expect positions_to_be_valid(taxon_with_5_products)
      end
    end

    context "replacing product's taxons" do
      before do
        p = taxon_with_5_products.products[1]
        p.taxons = []
        p.save!
      end

      it 'resets positions' do
        expect positions_to_be_valid(taxon_with_5_products)
      end
    end

    context 'destroying classification' do
      before do
        classification = taxon_with_5_products.classifications[1]
        classification.destroy
      end

      it 'resets positions' do
        expect positions_to_be_valid(taxon_with_5_products)
      end
    end

    describe 'counter cache' do
      let(:category) { create(:category) }
      let(:product) { create(:product) }

      # The direct category-side classification_count was dropped in 6.0; the category
      # now tracks membership via the descendant-inclusive products_count, kept in
      # sync by the Classification create/destroy callbacks (a leaf category's
      # products_count equals its direct count).
      describe 'products_count on category' do
        it 'increments when a classification is created' do
          expect {
            create(:product_category, category: category, product: product)
          }.to change { category.reload.products_count }.from(0).to(1)
        end

        it 'decrements when a classification is destroyed' do
          classification = create(:product_category, category: category, product: product)
          expect {
            classification.destroy
          }.to change { category.reload.products_count }.from(1).to(0)
        end

        it 'correctly counts multiple classifications' do
          products = create_list(:product, 3)
          products.each { |p| create(:product_category, category: category, product: p) }
          expect(category.reload.products_count).to eq(3)
        end
      end

      describe 'categories_count on product' do
        it 'increments when a classification is created' do
          expect {
            create(:product_category, category: category, product: product)
          }.to change { product.reload.categories_count }.from(0).to(1)
        end

        it 'decrements when a classification is destroyed' do
          classification = create(:product_category, category: category, product: product)
          expect {
            classification.destroy
          }.to change { product.reload.categories_count }.from(1).to(0)
        end

        it 'correctly counts multiple classifications' do
          taxons = create_list(:category, 3)
          taxons.each { |t| create(:product_category, category: t, product: product) }
          expect(product.reload.categories_count).to eq(3)
        end
      end
    end

    describe '.grouped_category_ids_for_products' do
      let(:category1) { create(:category) }
      let(:category2) { create(:category) }
      let(:category3) { create(:category) }
      let(:product1) { create(:product) }
      let(:product2) { create(:product) }
      let!(:classification1) { create(:product_category, category: category1, product: product1) }
      let!(:classification2) { create(:product_category, category: category2, product: product1) }
      let!(:classification3) { create(:product_category, category: category3, product: product2) }
      let(:expected_result) { [[product1.id, "#{category1.id},#{category2.id}"], [product2.id, category3.id.to_s]] }
      let(:product_ids) { [product1.id, product2.id] }
      let(:taxon_groups) { [category1.id, category2.id, category3.id] }

      it 'returns the correct category ids' do
        expect(described_class.grouped_category_ids_for_products(product_ids, taxon_groups)).to eq(expected_result)
      end

      context 'when empty category groups' do
        let(:taxon_groups) { [] }

        it 'returns an empty array' do
          expect(described_class.grouped_category_ids_for_products(product_ids, taxon_groups)).to eq([])
        end
      end

      context 'when empty product ids' do
        let(:product_ids) { [] }

        it 'returns an empty array' do
          expect(described_class.grouped_category_ids_for_products(product_ids, taxon_groups)).to eq([])
        end
      end
    end
  end
end
