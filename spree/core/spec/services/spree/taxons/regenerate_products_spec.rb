require 'spec_helper'

RSpec.describe Spree::Taxons::RegenerateProducts do
  subject(:regenerate_products) { described_class.call(taxon: taxon) }

  let!(:taxon) { create(:automatic_taxon, :any_match_policy, products: tagged_products) }
  let!(:tag_taxon_rule) { create(:tag_taxon_rule, taxon: taxon, value: 'tag') }

  let(:tagged_products) { create_list(:product_in_stock, 2, tag_list: 'tag') }

  let(:all_products) { tagged_products }

  context 'after changing rules' do
    let!(:other_tag_taxon_rule) { create(:tag_taxon_rule, :is_equal_to, taxon: taxon, value: 'other') }
    let!(:other_tagged_product) { create(:product_in_stock, tag_list: 'other') }

    let(:all_products) { [*tagged_products, other_tagged_product] }

    before do
      tag_taxon_rule.destroy!
      taxon.reload
    end

    it 're-matches products for an automatic taxon' do
      expect { regenerate_products }.to change(taxon.products, :count).from(2).to(1)
      expect(taxon.reload.products).to contain_exactly(other_tagged_product)
    end

    it 'updates classification_count on taxon' do
      expect { regenerate_products }.to change { taxon.reload.classification_count }.from(2).to(1)
    end

    it 'updates classification_count on products' do
      removed_product = tagged_products.first
      expect { regenerate_products }.to change { removed_product.reload.classification_count }.from(1).to(0)
    end
  end

  context 'when nothing changed' do
    before do
      taxon.reload
    end

    it "doesn't change the taxon" do
      expect { regenerate_products }.to_not change(taxon.products, :count)
      expect(taxon.reload.products).to contain_exactly(*tagged_products)
    end
  end

  context 'with manual order' do
    context 'when nothing changed' do
      it 'keeps products positions' do
        regenerate_products
        expect(taxon.reload.classifications.order(:position).pluck(:position)).to eq([1, 2])
      end
    end

    context 'when products added' do
      let!(:new_product) { create(:product) }

      let(:matching_rules_products) { double(ids: ([new_product] + taxon.products).map(&:id)) }

      before do
        allow(taxon).to receive(:products_matching_rules).and_return(matching_rules_products)
        taxon.classifications.order(position: :asc).last.move_to_top
      end

      it 'keeps products positions' do
        old_positions = taxon.classifications.reload.order(position: :asc).pluck(:product_id, :position)
        regenerate_products
        expect(taxon.products.order(position: :asc).limit(2).pluck(:id, :position)).to eq(old_positions)
        expect(taxon.reload.classifications.pluck(:position)).to match_array([1, 2, 3])
      end
    end

    context 'when some one product removed and 2 added' do
      let(:tagged_products) { create_list(:product_in_stock, 3, tag_list: 'tag') }
      let(:new_tagged_products) { create_list(:product_in_stock, 2, tag_list: 'tag') }

      let(:matching_rules_products) { double(ids: new_tagged_products.map(&:id) + [tagged_products.first.id] ) }

      before do
        allow(taxon).to receive(:products_matching_rules).and_return(matching_rules_products)
      end

      it 'keeps products positions' do
        old_positions = taxon.classifications.reload.order(position: :asc).limit(1).pluck(:product_id, :position)
        regenerate_products
        expect(taxon.products.order(position: :asc).limit(1).pluck(:id, :position)).to eq(old_positions)
        expect(taxon.reload.classifications.pluck(:position)).to match_array([1, 2, 3])
      end
    end

    context 'when some one product removed from middle of list and 2 added' do
      let(:tagged_products) { create_list(:product_in_stock, 3, tag_list: 'tag') }
      let(:new_tagged_products) { create_list(:product_in_stock, 2, tag_list: 'tag') }

      let(:current_taxon_products) { taxon.classifications.reload.order(position: :asc) }
      let(:matching_rules_products) { double(ids: (new_tagged_products.map(&:id) + [current_taxon_products.first.product_id, current_taxon_products.last.product_id]).shuffle ) }

      before do
        allow(taxon).to receive(:products_matching_rules).and_return(matching_rules_products)
      end

      it 'keeps products positions' do
        product_1 = current_taxon_products.first.product
        product_3 = current_taxon_products.third.product
        regenerate_products
        expect(taxon.classifications.reload.order(position: :asc).where(product: [product_1, product_3]).pluck(:position)).to eq([1,2])
        expect(taxon.reload.classifications.pluck(:position)).to match_array([1, 2, 3, 4])
      end
    end
  end
end
