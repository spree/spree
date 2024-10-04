require 'spec_helper'

module Spree
  describe Taxons::RemoveProducts do
    let(:service) { described_class }
    let(:taxons) { create_list(:taxon, 2) }
    let(:products) { create_list(:product, 3) }

    describe '#call' do
      subject { service.call(taxons: taxons, products: products) }

      before do
        # Add products to taxons initially
        Spree::Taxons::AddProducts.call(taxons: taxons, products: products)
      end

      it 'removes classifications for each taxon-product pair' do
        expect { subject }.to change { Spree::Classification.count }.by(-(taxons.size * products.size))
      end

      it 'resets the position for remaining classifications' do
        other_product = create(:product)
        Spree::Taxons::AddProducts.call(taxons: taxons, products: [other_product])

        subject
        taxons.each do |taxon|
          expect(taxon.classifications.pluck(:position)).to eq([1])
        end
      end

      it 'touches all products' do
        expect { subject }.to change { Spree::Product.where(id: products.pluck(:id)).pluck(:updated_at) }
      end

      it 'touches all taxons' do
        expect { subject }.to change { Spree::Taxon.where(id: taxons.pluck(:id)).pluck(:updated_at) }
      end

      it 'returns a successful result' do
        expect(subject.success?).to be true
        expect(subject.value).to eq true
      end
    end
  end
end
