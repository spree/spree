require 'spec_helper'

module Spree
  describe Categories::AddProducts do
    let(:service) { described_class }
    let(:categories) { create_list(:category, 2) }
    let(:products) { create_list(:product, 3) }

    describe '#call' do
      subject { service.call(categories: categories, products: products) }

      it 'creates product categories for each category-product pair' do
        expect { subject }.to change { Spree::ProductCategory.count }.by(categories.size * products.size)
      end

      it 'sets the correct position for each product category' do
        subject
        categories.each do |category|
          expect(category.product_categories.pluck(:position)).to eq((1..products.size).to_a)
        end
      end

      it 'touches all products' do
        expect { subject }.to change { Spree::Product.where(id: products.pluck(:id)).pluck(:updated_at) }
      end

      it "reindexes products" do
        allow_any_instance_of(Spree::Product).to receive(:search_indexing_enabled?).and_return(true)
        expect { subject }.to have_enqueued_job(Spree::SearchProvider::IndexJob).exactly(products.size).times
      end

      it 'touches all categories' do
        expect { subject }.to change { Spree::Category.where(id: categories.pluck(:id)).pluck(:updated_at) }
      end

      it 'returns a successful result' do
        expect(subject.success?).to be true
        expect(subject.value).to eq true
      end

      it 'updates products_count on categories' do
        expect { subject }.to change { categories.first.reload.products_count }.from(0).to(products.size)
          .and change { categories.second.reload.products_count }.from(0).to(products.size)
      end

      it 'updates categories_count on products' do
        expect { subject }.to change { products.first.reload.categories_count }.from(0).to(categories.size)
          .and change { products.second.reload.categories_count }.from(0).to(categories.size)
      end
    end
  end
end
