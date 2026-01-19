require 'spec_helper'

module Spree
  describe Taxons::AddProducts do
    let(:service) { described_class }
    let(:taxons) { create_list(:taxon, 2) }
    let(:products) { create_list(:product, 3) }

    describe '#call' do
      subject { service.call(taxons: taxons, products: products) }

      it 'creates classifications for each taxon-product pair' do
        expect { subject }.to change { Spree::Classification.count }.by(taxons.size * products.size)
      end

      it 'sets the correct position for each classification' do
        subject
        taxons.each do |taxon|
          expect(taxon.classifications.pluck(:position)).to eq((1..products.size).to_a)
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

      it 'updates classification_count on taxons' do
        expect { subject }.to change { taxons.first.reload.classification_count }.from(0).to(products.size)
          .and change { taxons.second.reload.classification_count }.from(0).to(products.size)
      end

      it 'updates classification_count on products' do
        expect { subject }.to change { products.first.reload.classification_count }.from(0).to(taxons.size)
          .and change { products.second.reload.classification_count }.from(0).to(taxons.size)
      end
    end
  end
end
