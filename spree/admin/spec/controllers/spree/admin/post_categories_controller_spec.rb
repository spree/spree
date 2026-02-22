require 'spec_helper'

RSpec.describe Spree::Admin::PostCategoriesController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe 'GET #index' do
    subject(:index) { get :index }

    it 'renders the list of post categories' do
      index

      expect(response).to render_template(:index)
      expect(assigns[:collection]).to contain_exactly(*store.post_categories)
    end
  end

  describe 'GET #select_options' do
    subject(:select_options) { get :select_options, format: :json }

    let!(:post_categories) { create_list(:post_category, 3, store: store) }
    let!(:other_store_category) { create(:post_category, store: create(:store)) }

    it 'returns post categories for the current store' do
      select_options

      json = JSON.parse(response.body)
      ids = json.map { |c| c['id'] }
      post_categories.each do |category|
        expect(ids).to include(category.id)
        expect(json).to include({ 'id' => category.id, 'name' => category.title })
      end
    end

    it 'does not include categories from other stores' do
      select_options

      json = JSON.parse(response.body)
      expect(json.map { |c| c['id'] }).not_to include(other_store_category.id)
    end
  end

  describe 'GET #new' do
    subject(:new) { get :new }

    it 'renders the new post category page' do
      new
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    subject(:create_category) { post :create, params: { post_category: post_category_params } }

    let(:post_category_params) do
      {
        title: 'New Category',
        description: 'This is a new category',
        slug: 'new-category'
      }
    end

    it 'creates a new post category' do
      expect { create_category }.to change(Spree::PostCategory, :count).by(1)

      category = Spree::PostCategory.last
      expect(category.title).to eq('New Category')
      expect(category.description.to_plain_text).to eq('This is a new category')
      expect(category.slug).to eq('new-category')
      expect(category.store).to eq(store)
    end
  end

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: post_category.to_param } }

    let(:post_category) { create(:post_category) }

    it 'renders the edit page' do
      edit
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    subject(:update_category) { put :update, params: { id: post_category.to_param, post_category: post_category_params } }

    let!(:post_category) { create(:post_category, store: store) }
    let(:post_category_params) do
      {
        title: 'Updated Category',
        description: 'This is an updated category',
        slug: 'updated-category'
      }
    end

    it 'updates the post category' do
      update_category
      post_category.reload

      expect(post_category.title).to eq('Updated Category')
      expect(post_category.description.to_plain_text).to eq('This is an updated category')
      expect(post_category.slug).to eq('updated-category')
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_category) { delete :destroy, params: { id: post_category.to_param } }

    let!(:post_category) { create(:post_category, store: store) }

    it 'destroys the post category' do
      expect { destroy_category }.to change(Spree::PostCategory, :count).by(-1)
      expect(response).to redirect_to(admin_post_categories_path)
    end
  end
end
