require 'spec_helper'

RSpec.describe Spree::Admin::PagesController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:theme) { create(:theme, store: store) }
  let(:page) { create(:custom_page, pageable: store) }

  describe 'GET #index' do
    let!(:page) { create(:custom_page, pageable: store) }

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end
  end

  describe 'GET #new' do
    it 'renders the new template' do
      get :new
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    let(:new_page) { Spree::Pages::Custom.last }

    context 'with valid attributes' do
      it 'creates a new page' do
        post :create, params: { page: { name: 'new page', slug: 'new-page' } }

        expect(new_page.pageable).to eq(store)
        expect(new_page.name).to eq('new page')
        expect(new_page.slug).to eq('new-page')
      end

      it 'redirects to page builder' do
        post :create, params: { page: { name: 'new page', slug: 'new-page' } }

        expect(response).to redirect_to(spree.edit_admin_theme_path(store.default_theme, page_id: new_page.id))
      end
    end

    context 'with invalid attributes' do
      it 'does not create a new page' do
        expect do
          post :create, params: { page: { name: '', slug: '' } }
        end.not_to change(Spree::Pages::Custom, :count)
      end

      it 'renders the new template with unprocessable entity status' do
        post :create, params: { page: { name: '', slug: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #edit' do
    it 'renders the edit template' do
      get :edit, params: { id: page.id }
      expect(response).to render_template(:edit)
    end
  end

  describe 'PATCH #update' do
    context 'with valid attributes' do
      before do
        post :update, params: { id: page.id, page: { name: 'very new name' } }
      end

      it 'updates a page' do
        page.reload
        expect(page.name).to eq('very new name')
      end

      it 'redirects to page builder' do
        expect(response).to redirect_to(spree.edit_admin_theme_path(store.default_theme, page_id: page.id))
      end
    end

    context 'with invalid attributes' do
      before do
        post :update, params: { id: page.id, page: { name: '', slug: '' } }
      end

      it 'renders the update template with unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the page' do
      delete :destroy, params: { id: page.id }
      expect(Spree::Pages::Custom.exists?(page.id)).to be_falsey
    end

    it 'deletes the page preview from session if it matches the deleted page' do
      session[:page_preview_id] = page.id
      delete :destroy, params: { id: page.id }
      expect(session[:page_preview_id]).to be_nil
    end

    it 'redirects to the pages index' do
      delete :destroy, params: { id: page.id }
      expect(response).to redirect_to(spree.admin_pages_path)
    end
  end
end
