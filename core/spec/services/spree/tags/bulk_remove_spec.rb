require 'spec_helper'

module Spree
  describe Tags::BulkRemove do
    let(:tag_names) { ['tag1', 'tag2', 'tag3'] }
    let(:products) { create_list(:product, 3) }
    let(:context) { 'tags' }

    describe '#call' do
      subject { described_class.call(tag_names: tag_names, records: products, context: context) }

      before do
        # Add tags to products initially
        Spree::Tags::BulkAdd.call(tag_names: tag_names, records: products, context: context)
      end

      it 'removes taggings for each product-tag pair' do
        expect { subject }.to change { Spree::Tagging.count }.by(-(products.size * tag_names.size))
      end

      it 'does not remove tags' do
        expect { subject }.not_to change { Spree::Tag.count }
      end

      it 'removes correct taggings' do
        subject
        products.each do |product|
          expect(product.tag_list_on(context)).to be_empty
        end
      end

      it 'touches all products' do
        expect { subject }.to change { Spree::Product.where(id: products.pluck(:id)).pluck(:updated_at) }
      end
    end
  end
end
