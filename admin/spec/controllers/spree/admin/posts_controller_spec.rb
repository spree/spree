require 'spec_helper'

RSpec.describe Spree::Admin::PostsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }

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

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: post.id } }

    let(:post) { create(:post) }

    it 'renders the edit page' do
      edit
      expect(response).to render_template(:edit)
    end
  end
end
