require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MediaController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product) }
  let!(:image) { create(:image, viewable: product) }

  before { request.headers.merge!(headers) }

  describe 'product assets' do
    describe 'GET #index' do
      it 'returns media for the product' do
        get :index, params: { product_id: product.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to be_an(Array)
        ids = json_response['data'].map { |a| a['id'] }
        expect(ids).to include(image.prefixed_id)
      end

      context 'with product from another store' do
        let(:other_store) { create(:store) }
        let(:other_product) { create(:product, store: other_store) }

        it 'returns 404' do
          get :index, params: { product_id: other_product.prefixed_id }, as: :json
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    describe 'POST #create' do
      it 'returns validation error without attachment' do
        post :create, params: {
          product_id: product.prefixed_id,
          alt: 'New image',
          position: 1
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'enqueues SaveFromUrlJob for the product when url is provided' do
        expect {
          post :create, params: {
            product_id: product.prefixed_id,
            url: 'https://example.com/image.jpg',
            position: 2
          }, as: :json
        }.to have_enqueued_job(Spree::Images::SaveFromUrlJob).with(
          product.id,
          'Spree::Product',
          'https://example.com/image.jpg',
          nil,
          2
        )

        expect(response).to have_http_status(:accepted)
      end
    end

    describe 'PATCH #update' do
      it 'updates the media alt text' do
        patch :update, params: {
          product_id: product.prefixed_id,
          id: image.prefixed_id,
          alt: 'Updated alt text'
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['alt']).to eq('Updated alt text')
        expect(image.reload.alt).to eq('Updated alt text')
      end

      it 'updates the media position' do
        patch :update, params: {
          product_id: product.prefixed_id,
          id: image.prefixed_id,
          position: 5
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(image.reload.position).to eq(5)
      end

      context 'with variant_ids on a product-level asset' do
        let!(:product_asset) { create(:image, viewable: product) }
        let!(:variant_a) { create(:variant, product: product) }
        let!(:variant_b) { create(:variant, product: product) }

        it 'links the picked variants' do
          expect {
            patch :update, params: {
              product_id: product.prefixed_id,
              id: product_asset.prefixed_id,
              variant_ids: [variant_a.to_param, variant_b.to_param]
            }, as: :json
          }.to change(Spree::VariantMedia, :count).by(2)

          expect(response).to have_http_status(:ok)
          expect(product_asset.variant_media.pluck(:variant_id)).to contain_exactly(variant_a.id, variant_b.id)
        end

        it 'replaces the link set on subsequent calls' do
          Spree::VariantMedia.create!(asset: product_asset, variant: variant_a)

          patch :update, params: {
            product_id: product.prefixed_id,
            id: product_asset.prefixed_id,
            variant_ids: [variant_b.to_param]
          }, as: :json

          expect(product_asset.variant_media.pluck(:variant_id)).to contain_exactly(variant_b.id)
        end

        it 'silently rejects variants from a different product' do
          other_variant = create(:variant, product: create(:product))

          patch :update, params: {
            product_id: product.prefixed_id,
            id: product_asset.prefixed_id,
            variant_ids: [other_variant.to_param]
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(product_asset.variant_media).to be_empty
        end
      end
    end

    describe 'DELETE #destroy' do
      it 'deletes the asset' do
        expect {
          delete :destroy, params: {
            product_id: product.prefixed_id,
            id: image.prefixed_id
          }, as: :json
        }.to change(product.media, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with legacy default-variant-pinned assets' do
      let!(:legacy_variant_image) { create(:image, viewable: product.default_variant) }

      it 'still surfaces legacy assets in the listing' do
        get :index, params: { product_id: product.prefixed_id }, as: :json

        ids = json_response['data'].map { |a| a['id'] }
        expect(ids).to include(legacy_variant_image.prefixed_id)
      end
    end
  end

  describe 'video' do
    describe 'POST #create' do
      it 'adds an external video from a link' do
        post :create, params: {
          product_id: product.prefixed_id,
          media_type: 'external_video',
          external_video_url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          alt: 'Product walkthrough'
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['media_type']).to eq('external_video')
        expect(json_response['video_provider']).to eq('youtube')
        expect(json_response['video_embed_url']).to eq('https://www.youtube.com/embed/dQw4w9WgXcQ')
        expect(json_response['poster_url']).to eq('https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg')
      end

      it 'adds a Vimeo video' do
        post :create, params: {
          product_id: product.prefixed_id,
          media_type: 'external_video',
          external_video_url: 'https://vimeo.com/123456789'
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['video_provider']).to eq('vimeo')
        expect(json_response['video_embed_url']).to eq('https://player.vimeo.com/video/123456789')
      end

      it 'rejects a link Spree cannot embed' do
        post :create, params: {
          product_id: product.prefixed_id,
          media_type: 'external_video',
          external_video_url: 'https://example.com/clip.mp4'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects an external video with no link' do
        post :create, params: {
          product_id: product.prefixed_id,
          media_type: 'external_video'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'PATCH #update' do
      let!(:video) do
        create(:external_video_asset, viewable: product,
                                      external_video_url: 'https://vimeo.com/123456789')
      end

      it 'swaps the video link' do
        patch :update, params: {
          product_id: product.prefixed_id,
          id: video.prefixed_id,
          external_video_url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['video_provider']).to eq('youtube')
      end

      it 'rejects a link Spree cannot embed' do
        patch :update, params: {
          product_id: product.prefixed_id,
          id: video.prefixed_id,
          external_video_url: 'https://example.com/clip.mp4'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(video.reload.external_video_url).to eq('https://vimeo.com/123456789')
      end
    end

    describe 'poster' do
      let(:poster_blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
          filename: 'poster.jpg',
          content_type: 'image/jpeg'
        )
      end

      it 'attaches a poster when the video is created' do
        post :create, params: {
          product_id: product.prefixed_id,
          media_type: 'external_video',
          external_video_url: 'https://vimeo.com/123456789',
          poster_signed_id: poster_blob.signed_id
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['poster_url']).to be_present
        expect(Spree::Media.find_by_prefix_id(json_response['id']).poster).to be_attached
      end

      it 'attaches a poster to an existing video' do
        video = create(:external_video_asset, viewable: product,
                                              external_video_url: 'https://vimeo.com/123456789')

        patch :update, params: {
          product_id: product.prefixed_id,
          id: video.prefixed_id,
          poster_signed_id: poster_blob.signed_id
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(video.reload.poster).to be_attached
        expect(json_response['poster_url']).to be_present
      end
    end

    describe 'focal point' do
      it 'writes the focal point on an image' do
        patch :update, params: {
          product_id: product.prefixed_id,
          id: image.prefixed_id,
          focal_point_x: 0.25,
          focal_point_y: 0.75
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(image.reload.focal_point).to eq({ x: 0.25, y: 0.75 })
      end
    end
  end

  describe 'variant assets' do
    let!(:variant) { create(:variant, product: product) }
    let!(:variant_image) { create(:image, viewable: variant) }

    describe 'GET #index' do
      it 'returns media for the variant' do
        get :index, params: { product_id: product.prefixed_id, variant_id: variant.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |a| a['id'] }
        expect(ids).to include(variant_image.prefixed_id)
        expect(ids).not_to include(image.prefixed_id)
      end
    end

    describe 'POST #create' do
      it 'enqueues SaveFromUrlJob for variant when url is provided' do
        expect {
          post :create, params: {
            product_id: product.prefixed_id,
            variant_id: variant.prefixed_id,
            url: 'https://example.com/variant.jpg'
          }, as: :json
        }.to have_enqueued_job(Spree::Images::SaveFromUrlJob).with(
          variant.id,
          'Spree::Variant',
          'https://example.com/variant.jpg',
          nil,
          nil
        )

        expect(response).to have_http_status(:accepted)
      end
    end

    describe 'PATCH #update' do
      it 'updates the variant asset' do
        patch :update, params: {
          product_id: product.prefixed_id,
          variant_id: variant.prefixed_id,
          id: variant_image.prefixed_id,
          alt: 'Variant image'
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(variant_image.reload.alt).to eq('Variant image')
      end
    end

    describe 'DELETE #destroy' do
      it 'deletes the variant asset' do
        expect {
          delete :destroy, params: {
            product_id: product.prefixed_id,
            variant_id: variant.prefixed_id,
            id: variant_image.prefixed_id
          }, as: :json
        }.to change(variant.images, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
