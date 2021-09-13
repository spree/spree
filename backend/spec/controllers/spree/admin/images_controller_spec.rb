require 'spec_helper'

module Spree
  module Admin
    describe ImagesController, type: :controller do
      stub_authorization!

      let(:store) { Spree::Store.default }
      let(:product) { create(:product, stores: [store]) }
      let(:product_in_other_store) { create(:product, stores: [create(:store)]) }

      describe '#index' do
        let!(:image_1) { create(:image, viewable: product.master) }
        let!(:image_2) { create(:image, viewable: product.master) }
        let!(:image_3) { create(:image, viewable: create(:variant)) }
        let!(:image_4) { create(:image, viewable: product_in_other_store.master) }

        it 'assigns the images for a requested product' do
          get :index, params: { product_id: product.slug }
          expect(assigns(:collection)).to include image_1
          expect(assigns(:collection)).to include image_2
          expect(assigns(:collection)).not_to include image_4
        end
      end

      describe '#destroy' do
        context 'when request format is javascript' do
          subject(:send_request) do
            delete :destroy, params: { product_id: product, id: image, format: :js }
          end

          let(:image) { create(:image, viewable: product.master) }

          shared_examples 'correct response' do
            it { expect(assigns(:image)).to eq(image) }
            it { expect(response).to have_http_status(:ok) }
          end

          context 'will successfully destroy image' do
            describe 'returns response' do
              before { send_request }

              it_behaves_like 'correct response'
              it { expect(flash[:success]).to eq('Image has been successfully removed!') }
            end
          end

          context 'cannot destroy image of other product' do
            let(:other_product) { create(:product, stores: [store]) }
            let(:image) { create(:image, viewable: other_product) }

            it { expect(send_request).to redirect_to(spree.admin_product_images_path(product)) }

            it do
              send_request
              expect(flash[:error]).to eq('Image is not found')
            end
          end

          context 'cannot destroy image of product from different store' do
            let(:product) { create(:product, stores: [create(:store)]) }
            before { send_request }

            it do
              expect(send_request).to redirect_to(spree.admin_product_images_path(product))
              expect(flash[:error]).to eq('Image is not found')
            end
          end
        end

        context 'when request format is html' do
          subject(:send_request) do
            delete :destroy, params: { product_id: product, id: image, format: :html }
          end

          let(:image) { create(:image, viewable: product.master) }

          shared_examples 'correct response' do
            it { expect(assigns(:image)).to eq(image) }
            it { expect(response).to have_http_status(:ok) }
          end

          context 'will successfully destroy image' do
            describe 'returns response' do
              before { send_request }

              it { expect(send_request).to redirect_to(spree.admin_product_images_path(product)) }
            end
          end

          context 'cannot destroy image of other product' do
            let(:other_product) { create(:product, stores: [store]) }
            let(:image) { create(:image, viewable: other_product) }

            it { expect(send_request).to redirect_to(spree.admin_product_images_path(product)) }

            it do
              send_request
              expect(flash[:error]).to eq('Image is not found')
            end
          end

          context 'cannot destroy image of product from different store' do
            let(:product) { create(:product, stores: [create(:store)]) }
            before { send_request }

            it do
              expect(send_request).to redirect_to(spree.admin_product_images_path(product))
              expect(flash[:error]).to eq('Image is not found')
            end
          end
        end
      end
    end
  end
end
