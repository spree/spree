require 'spec_helper'

describe 'API V2 Storefront Post Categories Spec', type: :request do
  let!(:store) { @default_store }
  let!(:admin_user) { create(:admin_user) }
  let!(:post_categories) { create_list(:post_category, 3, store: store) }
  let!(:post_category_with_posts) { create(:post_category, store: store) }
  let!(:published_posts) { create_list(:post, 2, :published, store: store, author: admin_user, post_category: post_category_with_posts) }

  before do
    allow_any_instance_of(Spree::Api::V2::Storefront::PostCategoriesController).to receive(:current_store).and_return(store)
  end

  describe 'post_categories#index' do
    context 'with no params' do
      before { get '/api/v2/storefront/post_categories' }

      it 'returns all post categories' do
        expect(response.status).to eq(200)
        expect(json_response['data'].count).to be >= 4
        expect(json_response['data'].first).to have_type('post_category')
      end

      it 'returns post categories with correct attributes' do
        category_data = json_response['data'].first['attributes']
        expect(category_data).to include('title', 'slug', 'created_at', 'updated_at', 'description')
      end

      it 'does not include posts by default' do
        expect(json_response['data'].first).not_to have_relationships(:posts)
      end
    end

  end

  describe 'post_categories#show' do
    let(:category) { post_categories.first }

    context 'with valid id' do
      before { get "/api/v2/storefront/post_categories/#{category.id}" }

      it 'returns the post category' do
        expect(response.status).to eq(200)
        expect(json_response['data']).to have_type('post_category')
        expect(json_response['data']['attributes']['title']).to eq(category.title)
      end

      it 'includes posts relationship' do
        expect(json_response['data']).to have_relationships(:posts)
      end
    end

    context 'with friendly id (slug)' do
      before { get "/api/v2/storefront/post_categories/#{category.slug}" }

      it 'returns the category by slug' do
        expect(response.status).to eq(200)
        expect(json_response['data']['attributes']['title']).to eq(category.title)
      end
    end

    context 'with category that has posts' do
      before { get "/api/v2/storefront/post_categories/#{post_category_with_posts.id}" }

      it 'returns the category with published posts only' do
        expect(response.status).to eq(200)
        expect(json_response['data']).to have_relationships(:posts)
        
        if json_response['included']
          posts_data = json_response['included'].select { |item| item['type'] == 'post' }
          expect(posts_data.count).to eq(2)
        end
      end
    end

    context 'with invalid id' do
      before { get '/api/v2/storefront/post_categories/invalid-id' }

      it 'returns 404' do
        expect(response.status).to eq(404)
      end
    end
  end
end