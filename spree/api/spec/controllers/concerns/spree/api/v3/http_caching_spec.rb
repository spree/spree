require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, status: 'active') }
  let!(:product2) { create(:product, status: 'active') }
  let!(:pos_channel) { create(:channel, store: store, code: 'pos', name: 'POS') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'Spree::Api::V3::HttpCaching' do
    describe 'Vary headers' do
      context 'for guest users' do
        it 'sets Vary header for CDN caching' do
          get :index

          expect(response.headers['Vary']).to eq('Accept, x-spree-currency, x-spree-locale, x-spree-channel')
        end
      end

      context 'for authenticated users' do
        before do
          request.headers['Authorization'] = "Bearer #{jwt_token}"
        end

        it 'sets Cache-Control to private, no-store' do
          get :index

          expect(response.headers['Cache-Control']).to include('private')
          expect(response.headers['Cache-Control']).to include('no-store')
        end

        it 'does not set Vary header' do
          get :index

          expect(response.headers['Vary']).to be_nil
        end
      end
    end

    describe '#cache_collection' do
      context 'for guest users' do
        it 'sets ETag header' do
          get :index

          expect(response.headers['ETag']).to be_present
        end

        it 'sets Cache-Control with public and max-age' do
          get :index

          expect(response.headers['Cache-Control']).to include('public')
          expect(response.headers['Cache-Control']).to include('max-age=300')
        end

        it 'sets stale-while-revalidate' do
          get :index

          expect(response.headers['Cache-Control']).to include('stale-while-revalidate=30')
        end

        it 'returns 200 when ETag does not match' do
          request.headers['If-None-Match'] = '"stale-etag"'
          get :index

          expect(response).to have_http_status(:ok)
        end

        it 'returns 304 Not Modified when the collection has not changed' do
          get :index
          etag = response.headers['ETag']

          request.headers['If-None-Match'] = etag
          get :index

          expect(response).to have_http_status(:not_modified)
        end

        it 'changes ETag when a product is updated' do
          get :index
          original_etag = response.headers['ETag']

          Timecop.travel(1.minute.from_now) do
            product.update!(name: 'Updated Product Name')

            get :index
            new_etag = response.headers['ETag']

            expect(new_etag).not_to eq(original_etag)
          end
        end

        it 'changes ETag when a product is added' do
          get :index
          original_etag = response.headers['ETag']

          create(:product, status: 'active')

          get :index
          new_etag = response.headers['ETag']

          expect(new_etag).not_to eq(original_etag)
        end

        it 'changes ETag when query params change' do
          get :index
          original_etag = response.headers['ETag']

          get :index, params: { q: { name_cont: 'test' } }
          filtered_etag = response.headers['ETag']

          expect(filtered_etag).not_to eq(original_etag)
        end

        it 'changes ETag when page changes' do
          get :index, params: { page: 1, limit: 1 }
          page1_etag = response.headers['ETag']

          get :index, params: { page: 2, limit: 1 }
          page2_etag = response.headers['ETag']

          expect(page2_etag).not_to eq(page1_etag)
        end

        it 'changes ETag when currency changes' do
          get :index
          original_etag = response.headers['ETag']

          request.headers['x-spree-currency'] = 'EUR'
          get :index
          eur_etag = response.headers['ETag']

          expect(eur_etag).not_to eq(original_etag)
        end

        # Publish the same products on both channels so the identical collection
        # is served either way — isolating the channel as the sole cache
        # dimension that differs (guards against a shared CDN cross-serving).
        context 'when the same products are visible on two channels' do
          before { pos_channel.add_products([product.id, product2.id]) }

          it 'changes ETag when the resolved channel changes' do
            get :index
            default_channel_etag = response.headers['ETag']

            request.headers['x-spree-channel'] = 'pos'
            get :index
            pos_channel_etag = response.headers['ETag']

            expect(pos_channel_etag).not_to eq(default_channel_etag)
          end

          it 'does not serve a 304 across channels for the same fresh ETag' do
            get :index
            default_channel_etag = response.headers['ETag']

            request.headers['x-spree-channel'] = 'pos'
            request.headers['If-None-Match'] = default_channel_etag
            get :index

            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'for authenticated users' do
        before do
          request.headers['Authorization'] = "Bearer #{jwt_token}"
        end

        it 'does not set ETag header' do
          get :index

          expect(response.headers['ETag']).to be_nil
        end

        it 'does not return 304' do
          get :index

          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe '#cache_resource' do
      context 'for guest users' do
        it 'sets ETag header' do
          get :show, params: { id: product.prefixed_id }

          expect(response.headers['ETag']).to be_present
        end

        it 'sets Cache-Control with public' do
          get :show, params: { id: product.prefixed_id }

          expect(response.headers['Cache-Control']).to include('public')
        end

        it 'returns 304 Not Modified when resource has not changed' do
          get :show, params: { id: product.prefixed_id }
          etag = response.headers['ETag']

          request.headers['If-None-Match'] = etag
          get :show, params: { id: product.prefixed_id }

          expect(response).to have_http_status(:not_modified)
        end

        it 'returns 200 when resource has changed' do
          get :show, params: { id: product.prefixed_id }
          etag = response.headers['ETag']

          product.update!(name: 'Updated Name')

          request.headers['If-None-Match'] = etag
          get :show, params: { id: product.prefixed_id }

          expect(response).to have_http_status(:ok)
        end

        # Publish the same product on both channels so it resolves either way —
        # isolating the channel as the sole cache dimension that differs.
        context 'when the product is visible on two channels' do
          before { pos_channel.add_products([product.id]) }

          it 'changes ETag when the resolved channel changes' do
            get :show, params: { id: product.prefixed_id }
            default_channel_etag = response.headers['ETag']

            request.headers['x-spree-channel'] = 'pos'
            get :show, params: { id: product.prefixed_id }
            pos_channel_etag = response.headers['ETag']

            expect(pos_channel_etag).not_to eq(default_channel_etag)
          end

          it 'does not serve a 304 across channels for the same fresh ETag' do
            get :show, params: { id: product.prefixed_id }
            default_channel_etag = response.headers['ETag']

            request.headers['x-spree-channel'] = 'pos'
            request.headers['If-None-Match'] = default_channel_etag
            get :show, params: { id: product.prefixed_id }

            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'for authenticated users' do
        before do
          request.headers['Authorization'] = "Bearer #{jwt_token}"
        end

        it 'does not set ETag header' do
          get :show, params: { id: product.prefixed_id }

          expect(response.headers['ETag']).to be_nil
        end

        it 'sets Cache-Control to private, no-store' do
          get :show, params: { id: product.prefixed_id }

          expect(response.headers['Cache-Control']).to include('private')
          expect(response.headers['Cache-Control']).to include('no-store')
        end
      end
    end
  end
end
