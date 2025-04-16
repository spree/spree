require 'spec_helper'

module Spree
  describe Classification, type: :model do
    let(:store) { @default_store }

    # Regression test for #3494
    let(:taxon_with_5_products) do
      products = []
      5.times do
        products << create(:base_product, stores: [store])
      end

      create(:taxon, products: products)
    end

    it 'cannot link the same taxon to the same product more than once' do
      product = create(:product, stores: [store])
      taxon = create(:taxon)
      expect { product.taxons << taxon }.not_to raise_error
      expect { product.taxons << taxon }.to raise_error(ActiveRecord::RecordInvalid)
    end

    def positions_to_be_valid(taxon)
      positions = taxon.reload.classifications.map(&:position)
      expect(positions).to eq((1..taxon.classifications.count).to_a)
    end

    it 'has a valid fixtures' do
      expect positions_to_be_valid(taxon_with_5_products)
      expect(Spree::Classification.count).to eq 5
    end

    context 'removing product from taxon' do
      before do
        p = taxon_with_5_products.products[1]
        expect(p.classifications.first.position).to eq(2)
        taxon_with_5_products.products.destroy(p)
      end

      it 'resets positions' do
        expect positions_to_be_valid(taxon_with_5_products)
      end
    end

    context "replacing taxon's products" do
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

    context 'removing taxon from product' do
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

    describe '.grouped_taxon_ids_for_products' do
      let(:taxon1) { create(:taxon) }
      let(:taxon2) { create(:taxon) }
      let(:taxon3) { create(:taxon) }
      let(:product1) { create(:product) }
      let(:product2) { create(:product) }
      let!(:classification1) { create(:classification, taxon: taxon1, product: product1) }
      let!(:classification2) { create(:classification, taxon: taxon2, product: product1) }
      let!(:classification3) { create(:classification, taxon: taxon3, product: product2) }
      let(:expected_result) { [[product1.id, "#{taxon1.id},#{taxon2.id}"], [product2.id, taxon3.id.to_s]] }
      let(:product_ids) { [product1.id, product2.id] }
      let(:taxon_groups) { [taxon1.id, taxon2.id, taxon3.id] }

      it 'returns the correct taxon ids' do
        expect(described_class.grouped_taxon_ids_for_products(product_ids, taxon_groups)).to eq(expected_result)
      end

      context 'when empty taxon groups' do
        let(:taxon_groups) { [] }

        it 'returns an empty array' do
          expect(described_class.grouped_taxon_ids_for_products(product_ids, taxon_groups)).to eq([])
        end
      end

      context 'when empty product ids' do
        let(:product_ids) { [] }

        it 'returns an empty array' do
          expect(described_class.grouped_taxon_ids_for_products(product_ids, taxon_groups)).to eq([])
        end
      end
    end
  end
end
