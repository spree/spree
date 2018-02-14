require 'spec_helper'

module Spree
  describe Api::V1::ImagesController, type: :controller do
    render_views

    let!(:product) { create(:product) }
    let!(:attributes) do
      [:id, :position, :attachment_content_type,
       :attachment_file_name, :type, :attachment_updated_at, :attachment_width,
       :attachment_height, :alt]
    end

    before do
      stub_authentication!
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'can learn how to create a new image' do
        api_get :new, product_id: product.id
        expect(json_response['attributes']).to eq(attributes.map(&:to_s))
        expect(json_response['required_attributes']).to be_empty
      end

      it 'can upload a new image for a variant' do
        expect do
          api_post :create,
                   image: { attachment: upload_image('thinking-cat.jpg'),
                            viewable_type: 'Spree::Variant',
                            viewable_id: product.master.to_param },
                   product_id: product.id
          expect(response.status).to eq(201)
          expect(json_response).to have_attributes(attributes)
        end.to change(Image, :count).by(1)
      end

      it "can't upload a new image for a variant without attachment" do
        api_post :create,
                 image: { viewable_type: 'Spree::Variant',
                          viewable_id: product.master.to_param },
                 product_id: product.id
        expect(response.status).to eq(422)
      end

      context 'working with an existing image' do
        let!(:product_image) { product.master.images.create!(attachment: image('thinking-cat.jpg')) }

        it 'can get a single product image' do
          api_get :show, id: product_image.id, product_id: product.id
          expect(response.status).to eq(200)
          expect(json_response).to have_attributes(attributes)
        end

        it 'can get a single variant image' do
          api_get :show, id: product_image.id, variant_id: product.master.id
          expect(response.status).to eq(200)
          expect(json_response).to have_attributes(attributes)
        end

        it 'can get a list of product images' do
          api_get :index, product_id: product.id
          expect(response.status).to eq(200)
          expect(json_response).to have_key('images')
          expect(json_response['images'].first).to have_attributes(attributes)
        end

        it 'can get a list of variant images' do
          api_get :index, variant_id: product.master.id
          expect(response.status).to eq(200)
          expect(json_response).to have_key('images')
          expect(json_response['images'].first).to have_attributes(attributes)
        end

        it 'can update image data' do
          expect(product_image.position).to eq(1)
          api_post :update, image: { position: 2 }, id: product_image.id, product_id: product.id
          expect(response.status).to eq(200)
          expect(json_response).to have_attributes(attributes)
          expect(product_image.reload.position).to eq(2)
        end

        it "can't update an image without attachment" do
          api_post :update,
                   id: product_image.id, product_id: product.id
          expect(response.status).to eq(422)
        end

        it 'can delete an image' do
          api_delete :destroy, id: product_image.id, product_id: product.id
          expect(response.status).to eq(204)
          expect { product_image.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context 'as a non-admin' do
      it 'cannot create an image' do
        api_post :create, product_id: product.id
        assert_unauthorized!
      end

      it 'cannot update an image' do
        api_put :update, id: 1, product_id: product.id
        assert_not_found!
      end

      it 'cannot delete an image' do
        api_delete :destroy, id: 1, product_id: product.id
        assert_not_found!
      end
    end
  end
end
