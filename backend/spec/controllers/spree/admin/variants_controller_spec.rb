require 'spec_helper'

module Spree
  module Admin
    describe VariantsController, type: :controller do
      stub_authorization!

      describe '#index' do
        let(:product) { create(:product) }
        let!(:variant_1) { create(:variant, product: product) }
        let!(:variant_2) { create(:variant, product: product) }

        context 'deleted is not requested' do
          it 'assigns the variants for a requested product' do
            spree_get :index, product_id: product.slug
            expect(assigns(:collection)).to include variant_1
            expect(assigns(:collection)).to include variant_2
          end
        end

        context 'deleted is requested' do
          before { variant_2.destroy }

          it 'assigns only deleted variants for a requested product' do
            spree_get :index, product_id: product.slug, deleted: 'on'
            expect(assigns(:collection)).not_to include variant_1
            expect(assigns(:collection)).to include variant_2
          end
        end
      end

      describe '#destroy' do
        subject(:send_request) do
          spree_delete :destroy, product_id: product, id: variant, format: :js
        end

        let(:variant) { mock_model(Spree::Variant) }
        let(:variants) { double(ActiveRecord::Relation) }
        let(:product) { mock_model(Spree::Product) }
        let(:products) { double(ActiveRecord::Relation) }

        before do
          allow(Spree::Product).to receive(:friendly).and_return(products)
          allow(products).to receive(:find).with(product.id.to_s).and_return(product)
          allow(product).to receive_message_chain(:variants, :find).with(variant.id.to_s).and_return(variants)

          allow(Spree::Variant).to receive(:find).with(variant.id.to_s).and_return(variant)
        end

        describe 'expects to receive' do
          after { send_request }

          it { expect(Spree::Product).to receive(:friendly).and_return(products) }
          it { expect(products).to receive(:find).with(product.id.to_s).and_return(product) }
          it { expect(product).to receive_message_chain(:variants, :find).with(variant.id.to_s).and_return(variants) }
          it { expect(Spree::Variant).to receive(:find).with(variant.id.to_s).and_return(variant) }
        end

        shared_examples 'correct response' do
          it { expect(assigns(:variant)).to eq(variant) }
          it { expect(response).to have_http_status(:ok) }
        end

        context 'will successfully destroy variant' do
          before { allow(variant).to receive(:destroy).and_return(true) }

          describe 'expects to receive' do
            after { send_request }

            it { expect(variant).to receive(:destroy).and_return(true) }
          end

          describe 'returns response' do
            before { send_request }

            it_behaves_like 'correct response'
            it { expect(flash[:success]).to eq(Spree.t('notice_messages.variant_deleted')) }
          end
        end

        context 'will not successfully destroy product' do
          let(:error_msg) { 'Failed to delete' }

          before do
            allow(variant).to receive_message_chain(:errors, :full_messages).and_return([error_msg])
            allow(variant).to receive(:destroy).and_return(false)
          end

          describe 'expects to receive' do
            after { send_request }

            it { expect(variant).to receive_message_chain(:errors, :full_messages).and_return([error_msg]) }
            it { expect(variant).to receive(:destroy).and_return(false) }
          end

          describe 'returns response' do
            before { send_request }

            it_behaves_like 'correct response'

            it { expect(flash[:error]).to eq(Spree.t('notice_messages.variant_not_deleted', error: error_msg)) }
          end
        end
      end
    end
  end
end
