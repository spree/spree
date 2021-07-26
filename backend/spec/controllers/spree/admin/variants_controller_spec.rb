require 'spec_helper'

module Spree
  module Admin
    describe VariantsController, type: :controller do
      stub_authorization!

      let(:store) { Spree::Store.default }
      let(:product) { create(:product, stores: [store]) }

      describe '#index' do
        let!(:variant_1) { create(:variant, product: product) }
        let!(:variant_2) { create(:variant, product: product) }
        let!(:variant_3) { create(:variant, product: create(:product)) }

        context 'deleted is not requested' do
          it 'assigns the variants for a requested product' do
            get :index, params: { product_id: product.slug }
            expect(assigns(:collection)).to include variant_1
            expect(assigns(:collection)).to include variant_2
            expect(assigns(:collection)).not_to include variant_3
          end
        end

        context 'deleted is requested' do
          before { variant_2.destroy }

          it 'assigns only deleted variants for a requested product' do
            get :index, params: { product_id: product.slug, q: { deleted_at_null: '1' } }
            expect(assigns(:collection)).not_to include variant_1
            expect(assigns(:collection)).to include variant_2
          end
        end
      end

      describe '#destroy' do
        subject(:send_request) do
          delete :destroy, params: { product_id: product, id: variant, format: :js }
        end

        let(:variant) { create(:variant, product: product) }

        shared_examples 'correct response' do
          it { expect(assigns(:variant)).to eq(variant) }
          it { expect(response).to have_http_status(:ok) }
        end

        context 'will successfully destroy variant' do
          describe 'returns response' do
            before { send_request }

            it_behaves_like 'correct response'
            it { expect(flash[:success]).to eq(Spree.t('notice_messages.variant_deleted')) }
          end
        end

        context 'cannot destroy variant of other product' do
          let(:other_product) { create(:product, stores: [store]) }
          let(:variant) { create(:variant, product: other_product) }

          it { expect(send_request).to redirect_to(spree.admin_product_variants_path(product)) }

          it do
            send_request
            expect(flash[:error]).to eq('Variant is not found')
          end
        end

        context 'cannot destroy variant of product from different store' do
          let(:product) { create(:product, stores: [create(:store)]) }

          it { expect { send_request }.to raise_error(ActiveRecord::RecordNotFound) }
        end
      end
    end
  end
end
