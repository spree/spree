require 'spec_helper'

describe 'API V2 Storefront Posts Spec', type: :request do
  let(:store) { @default_store }
  let!(:admin_user) { create(:admin_user) }
  let!(:post_category) { create(:post_category, store: store) }
  let!(:published_posts) { create_list(:post, 3, :published, store: store, author: admin_user, post_category: post_category) }
  let!(:unpublished_post) { create(:post, store: store, author: admin_user, published_at: nil) }

  before do
    allow_any_instance_of(Spree::Api::V2::Storefront::PostsController).to receive(:current_store).and_return(store)
  end

  describe 'posts#index' do
    context 'with no params' do
      before do
        allow_any_instance_of(Spree::Api::V2::Storefront::PostsController).to receive(:current_store).and_return(store)
        get '/api/v2/storefront/posts'
      end

      it 'returns only published posts' do
        expect(response.status).to eq(200)
        expect(json_response['data'].count).to eq(3)
        expect(json_response['data'].first).to have_type('post')
      end

      it 'returns posts with correct attributes' do
        post_data = json_response['data'].first['attributes']
        expect(post_data).to include(
          'title', 'slug', 'published_at', 'meta_title', 'meta_description',
          'created_at', 'updated_at', 'excerpt', 'content', 'description',
          'shortened_description', 'author_name', 'post_category_title', 'tags'
        )
      end

      it 'includes post category relationship' do
        expect(json_response['data'].first).to have_relationships(:post_category)
      end
    end

    context 'with filtering by category' do
      let!(:another_category) { create(:post_category, store: store) }
      let!(:posts_in_another_category) { create_list(:post, 2, :published, store: store, author: admin_user, post_category: another_category) }

      before { get "/api/v2/storefront/posts?filter[category_ids]=#{post_category.id}" }

      it 'returns only posts from specified category' do
        expect(response.status).to eq(200)
        expect(json_response['data'].count).to eq(3)
        json_response['data'].each do |post_data|
          expect(post_data['relationships']['post_category']['data']['id']).to eq(post_category.id.to_s)
        end
      end
    end

    context 'with search query' do
      let!(:searchable_post) { create(:post, :published, title: 'Special Search Title', store: store, author: admin_user) }

      before { get '/api/v2/storefront/posts?q=Special' }

      it 'returns posts matching search query' do
        expect(response.status).to eq(200)
        expect(json_response['data'].count).to eq(1)
        expect(json_response['data'].first['attributes']['title']).to eq('Special Search Title')
      end
    end

    context 'with sorting' do
      before do
        published_posts.first.update(published_at: 1.day.ago)
        published_posts.last.update(published_at: 1.hour.ago)
      end

      before { get '/api/v2/storefront/posts?sort_by=published-newest' }

      it 'returns posts sorted by published date' do
        expect(response.status).to eq(200)
        expect(json_response['data'].count).to eq(3)
        
        published_dates = json_response['data'].map { |post| post['attributes']['published_at'] }
        expect(published_dates).to eq(published_dates.sort.reverse)
      end
    end

    context 'with tags filtering' do
      let!(:tagged_post) { create(:post, :published, tag_list: ['ruby', 'rails'], store: store, author: admin_user) }

      before { get '/api/v2/storefront/posts?filter[tags]=ruby,rails' }

      it 'returns posts with specified tags' do
        expect(response.status).to eq(200)
        expect(json_response['data'].any? { |post| post['attributes']['tags'].include?('ruby') }).to be true
      end
    end
  end

  describe 'posts#show' do
    let(:post) { published_posts.first }

    context 'with valid id' do
      before { get "/api/v2/storefront/posts/#{post.id}" }

      it 'returns the post' do
        expect(response.status).to eq(200)
        expect(json_response['data']).to have_type('post')
        expect(json_response['data']['attributes']['title']).to eq(post.title)
      end

      it 'includes all post attributes' do
        post_attributes = json_response['data']['attributes']
        expect(post_attributes).to include(
          'title', 'slug', 'published_at', 'excerpt', 'content',
          'author_name', 'post_category_title', 'tags'
        )
      end
    end

    context 'with friendly id (slug)' do
      before { get "/api/v2/storefront/posts/#{post.slug}" }

      it 'returns the post by slug' do
        expect(response.status).to eq(200)
        expect(json_response['data']['attributes']['title']).to eq(post.title)
      end
    end

    context 'with unpublished post id' do
      before { get "/api/v2/storefront/posts/#{unpublished_post.id}" }

      it 'returns 404 for unpublished posts' do
        expect(response.status).to eq(404)
      end
    end

    context 'with invalid id' do
      before { get '/api/v2/storefront/posts/invalid-id' }

      it 'returns 404' do
        expect(response.status).to eq(404)
      end
    end
  end
end