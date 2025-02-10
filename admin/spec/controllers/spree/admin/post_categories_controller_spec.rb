require 'spec_helper'

RSpec.describe Spree::Admin::PostCategoriesController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }

  describe 'GET #index' do
    subject(:index) { get :index }

    it 'renders the list of post categories' do
      index

      expect(response).to render_template(:index)
      expect(assigns[:collection]).to contain_exactly(*store.post_categories)
    end
  end

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: post_category.id } }

    let(:post_category) { create(:post_category) }

    it 'renders the edit page' do
      edit
      expect(response).to render_template(:edit)
    end
  end
end
