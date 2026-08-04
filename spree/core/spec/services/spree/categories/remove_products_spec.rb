require 'spec_helper'

module Spree
  describe Categories::RemoveProducts do
    let(:service) { described_class }
    let(:categories) { create_list(:category, 2) }
    let(:products) { create_list(:product, 3) }

    describe '#call' do
      subject { service.call(categories: categories, products: products) }

      before do
        # Add products to categories initially
        Spree::Categories::AddProducts.call(categories: categories, products: products)
      end

      it 'removes product categories for each category-product pair' do
        expect { subject }.to change { Spree::ProductCategory.count }.by(-(categories.size * products.size))
      end

      it 'resets the position for remaining product categories' do
        other_product = create(:product)
        Spree::Categories::AddProducts.call(categories: categories, products: [other_product])

        subject
        categories.each do |category|
          expect(category.product_categories.pluck(:position)).to eq([1])
        end
      end

      it 'touches all products' do
        expect { subject }.to change { Spree::Product.where(id: products.pluck(:id)).pluck(:updated_at) }
      end

      it 'touches all categories' do
        expect { subject }.to change { Spree::Category.where(id: categories.pluck(:id)).pluck(:updated_at) }
      end

      it "reindexes products" do
        allow_any_instance_of(Spree::Product).to receive(:search_indexing_enabled?).and_return(true)
        expect { subject }.to have_enqueued_job(Spree::SearchProvider::IndexJob).exactly(products.size).times
      end

      it 'returns a successful result' do
        expect(subject.success?).to be true
        expect(subject.value).to eq true
      end

      it 'updates products_count on categories' do
        expect { subject }.to change { categories.first.reload.products_count }.from(products.size).to(0)
          .and change { categories.second.reload.products_count }.from(products.size).to(0)
      end

      it 'updates categories_count on products' do
        expect { subject }.to change { products.first.reload.categories_count }.from(categories.size).to(0)
          .and change { products.second.reload.categories_count }.from(categories.size).to(0)
      end
    end
  end
end
