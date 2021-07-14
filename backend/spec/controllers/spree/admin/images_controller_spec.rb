require 'spec_helper'

module Spree
  module Admin
    describe ImagesController, type: :controller do
      stub_authorization!

      let(:store) { Spree::Store.default }
      let(:product) { create(:product, stores: [store]) }

      describe '#index' do
        let!(:image_1) { create(:image, viewable: product.master) }
        let!(:image_2) { create(:image, viewable: product.master) }
        let!(:image_3) { create(:image, viewable: create(:variant)) }

        it 'assigns the images for a requested product' do
          get :index, params: { product_id: product.slug }
          expect(assigns(:collection)).to include image_1
          expect(assigns(:collection)).to include image_2
          expect(assigns(:collection)).not_to include image_3
        end
      end

      describe '#destroy' do
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

          it { expect { send_request }.to raise_error(ActiveRecord::RecordNotFound) }
        end
      end
    end
  end
end
