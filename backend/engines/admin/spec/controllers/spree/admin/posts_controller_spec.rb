require 'spec_helper'

RSpec.describe Spree::Admin::PostsController, type: :controller do
  stub_authorization!
  render_views

  let(:author_admin_user) { create(:admin_user) }
  let(:post_category) { create(:post_category, store: store) }
  let(:published_at) { '2025-05-24 00:00:00' }

  let(:store) { @default_store }

  describe 'GET #index' do
    subject(:index) { get :index }

    let!(:posts) { create_list(:post, 3) }
    let!(:other_posts) { create_list(:post, 2, store: create(:store)) }

    it 'renders the list of posts' do
      index

      expect(response).to render_template(:index)
      expect(assigns[:collection]).to contain_exactly(*store.posts)
    end
  end

  describe 'GET #select_options' do
    subject(:select_options) { get :select_options }

    let!(:published_posts) { create_list(:post, 2, published_at: 1.day.ago) }
    let!(:draft_posts) { create_list(:post, 2, published_at: nil) }

    it 'lists published posts for select options' do
      select_options

      expect(JSON.parse(response.body)).to contain_exactly(
        { 'id' => published_posts[0].id, 'name' => published_posts[0].title },
        { 'id' => published_posts[1].id, 'name' => published_posts[1].title }
      )
    end
  end

  describe 'GET #new' do
    subject(:new) { get :new }

    it 'renders the new post page' do
      new
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    subject(:create_post) { post :create, params: { post: post_params } }

    let(:post_params) do
      {
        title: 'New Post',
        content: 'This is a new post',
        excerpt: "Excerpt for SEO",
        published_at: published_at,
        author_id: author_admin_user.id,
        image: fixture_file_upload('logo.png', 'image/png'),
        meta_title: 'New Post for SEO',
        meta_description: 'This is a new post for SEO',
        tag_list: ['SEO', 'VIP'],
        slug: "my-new-post",
        post_category_id: post_category.id
      }
    end

    it 'creates a new post' do
      expect { create_post }.to change(Spree::Post, :count).by(1)

      post = Spree::Post.last
      expect(post.title).to eq('New Post')
      expect(post.content.to_plain_text).to eq('This is a new post')
      expect(post.excerpt.to_plain_text).to eq("Excerpt for SEO")
      expect(post.published_at).to eq(published_at)
      expect(post.author).to eq(author_admin_user)
      expect(post.post_category).to eq(post_category)
      expect(post.image).to be_attached
      expect(post.meta_title).to eq('New Post for SEO')
      expect(post.meta_description).to eq('This is a new post for SEO')
      expect(post.tag_list).to match_array(['SEO', 'VIP'])
      expect(post.slug).to eq("my-new-post")
      expect(post.post_category).to eq(post_category)
    end
  end

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: post.to_param } }

    let(:post) { create(:post) }

    it 'renders the edit page' do
      edit
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    subject(:update_post) { put :update, params: { id: post.to_param, post: post_params } }

    let!(:post) { create(:post, store: store) }
    let(:post_params) do
      {
        title: 'Updated Post',
        content: 'This is an updated post',
        excerpt: "Updated excerpt for SEO",
        published_at: published_at,
        author_id: author_admin_user.id,
        image: fixture_file_upload('logo.png', 'image/png'),
        meta_title: 'Updated Post for SEO',
        meta_description: 'This is an updated post for SEO',
        tag_list: ['Updated', 'VIP'],
        post_category_id: post_category.id
      }
    end

    it 'updates the post' do
      update_post
      post.reload

      expect(post.title).to eq('Updated Post')
      expect(post.content.to_plain_text).to eq('This is an updated post')
      expect(post.excerpt.to_plain_text).to eq("Updated excerpt for SEO")
      expect(post.published_at).to eq(published_at)
      expect(post.author).to eq(author_admin_user)
      expect(post.post_category).to eq(post_category)
      expect(post.image).to be_attached
      expect(post.meta_title).to eq('Updated Post for SEO')
      expect(post.meta_description).to eq('This is an updated post for SEO')
      expect(post.tag_list).to match_array(['Updated', 'VIP'])
      expect(post.post_category).to eq(post_category)
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_post) { delete :destroy, params: { id: post.to_param } }

    let!(:post) { create(:post, store: store) }

    it 'destroys the post' do
      destroy_post

      expect(post.reload.deleted_at).not_to be_nil

      expect(response).to redirect_to(admin_posts_path)
    end
  end
end
