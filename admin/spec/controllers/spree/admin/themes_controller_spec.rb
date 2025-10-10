require 'spec_helper'

RSpec.describe Spree::Admin::ThemesController, type: :controller do
  stub_authorization!
  render_views

  let!(:theme) { create(:theme) }
  let(:theme_preview) { theme.create_preview }
  let(:page) { create(:page, pageable: theme) }
  let(:page_preview) { page.create_preview }

  describe 'GET #index' do
    it 'assigns @themes and renders the index template' do
      get :index
      expect(assigns(:themes)).to be_kind_of(ActiveRecord::Relation)
      expect(response).to render_template('index')
    end
  end

  describe 'GET #edit' do
    it 'assigns @theme, @page, and @page_preview' do
      expect { get :edit, params: { id: theme.id } }.to change(Spree::Theme, :count).by(1).and change(Spree::Page, :count).by(1)
      expect(assigns(:page)).to be_a(Spree::Pages::Homepage)
      expect(assigns(:page_preview)).to be_a(Spree::Page)
    end
  end

  describe 'PUT #update_with_page' do
    it 'promotes theme_preview and page_preview' do
      put :update_with_page, params: { id: theme.id, theme_preview_id: theme_preview.id, page_preview_id: page_preview.id }
      expect(flash[:success]).to eq('Changes published!')

      expect(response).to redirect_to(spree.edit_admin_theme_path(theme_preview, page_id: page_preview))
    end
  end

  describe 'PUT #update' do
    it 'updates the theme' do
      expect do
        put :update, params: { id: theme.id, theme: { preferred_primary_color: '#0090FE', preferred_font_family: 'Inconsolata' }, format: :turbo_stream }
      end.to change { theme.reload.preferred_primary_color }.to('#0090FE')
        .and change { theme.reload.preferred_font_family }.to('Inconsolata')
    end
  end

  describe 'PUT #publish' do
    it 'sets the theme as default' do
      put :publish, params: { id: theme.id }, format: :turbo_stream
      expect(flash[:success]).to eq('Theme is now live')
      expect(response).to redirect_to(admin_themes_path)
    end
  end

  describe '#create' do
    it 'creates a new theme' do
      expect { post :create, params: { theme: { type: 'Spree::Themes::Default' } } }.to change(Spree::Theme, :count).by(1)

      expect(flash[:success]).to include('successfully created')
      expect(response).to redirect_to(spree.edit_admin_theme_path(Spree::Theme.last))
    end
  end

  describe 'POST #clone' do
    it 'duplicates the theme' do
      expect { post :clone, params: { id: theme.id } }.to change(Spree::Theme, :count).by(1)
      expect(flash[:success]).to eq(Spree.t('theme_copied'))
      expect(response).to redirect_to(spree.admin_themes_path)
    end
  end
end
