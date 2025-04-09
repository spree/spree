require 'spec_helper'

describe Spree::ProductsController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:preview_id) { nil }

  describe '#index' do
    subject { get :index }

    it 'renders the Shop All page' do
      subject

      expect(response).to render_template(:index)
      expect(assigns(:current_page)).to be_a(Spree::Pages::ShopAll)
    end

    context 'when filtering' do
      let(:taxon) { create(:taxon) }

      context 'by one taxon' do
        let(:product) { create(:product, stores: [store], taxons: [taxon]) }

        before do
          product
          get :index, params: { filter: { taxon_ids: [taxon.id] } }
        end

        it 'returns one product' do
          expect(assigns(:storefront_products).records).to eq([product])
        end
      end

      context 'by multiple taxons' do
        let(:taxon2) { create(:taxon) }

        context 'and product is associated with both taxons' do
          let(:product) { create(:product, stores: [store], taxons: [taxon, taxon2]) }

          before do
            product
            get :index, params: { filter: { taxon_ids: [taxon.id, taxon2.id] } }
          end

          it 'returns the product' do
            expect(assigns(:storefront_products).records).to eq([product])
          end
        end

        context 'and product is associated with only one of the taxons' do
          let(:product) { create(:product, stores: [store], taxons: [taxon]) }

          before do
            product
            get :index, params: { filter: { taxon_ids: [taxon.id, taxon2.id] } }
          end

          it 'does not return the product' do
            expect(assigns(:storefront_products).records).to be_empty
          end
        end
      end
    end
  end

  describe '#show' do
    subject { get :show, params: { id: product.slug, preview_id: preview_id } }

    shared_examples 'product not found' do
      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'when product is a draft' do
      before { product.update(status: :draft) }

      context 'when preview_id is specified' do
        let(:preview_id) { product.id }

        context 'when preview_id is valid' do
          it 'returns product page' do
            subject
            expect(response).to be_successful
          end
        end

        context 'when preview_id is not valid' do
          let(:preview_id) { 'wrong_id' }

          it_behaves_like 'product not found'
        end
      end

      context 'when preview_id is not specified' do
        it_behaves_like 'product not found'
      end
    end

    context 'when product is not a draft' do
      it 'returns product page' do
        subject
        expect(response).to be_successful
      end
    end

    context 'when product is not found' do
      before { product.destroy }

      it_behaves_like 'product not found'
    end
  end

  describe '#related' do
    subject { get :related, params: { id: product.slug, section_id: section.id } }
    let(:section) { store.default_theme.pages.product_details.first.sections.related_products.first }

    it 'responds successfully' do
      subject

      expect(response).to be_successful
    end
  end
end
