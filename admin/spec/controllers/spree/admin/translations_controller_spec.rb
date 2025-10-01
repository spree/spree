require 'spec_helper'

RSpec.describe Spree::Admin::TranslationsController, type: :controller do
  stub_authorization!
  render_views

  let(:product) { create(:product, name: 'Original Name') }
  let(:resource_type) { 'Spree::Product' }
  let(:translation_locale) { 'fr' }
  let(:translated_name) { 'Nom Français' }

  before do
    allow_any_instance_of(Spree::Store).to receive(:supported_locales_list).and_return(['en', 'fr'])
    allow(controller).to receive(:current_store).and_return(Spree::Store.default)
  end

  describe 'GET #edit' do
    it 'assigns @resource and renders the edit template' do
      get :edit, params: { resource_type: resource_type, id: product.slug, translation_locale: translation_locale }
      expect(response).to render_template(:edit)
      expect(assigns(:resource)).to eq(product)
      expect(assigns(:locales)).to include('fr')
      expect(assigns(:locales)).not_to include('en')
    end

    context 'when resource_type is missing' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :edit, params: { id: product.slug, resource_type: '', translation_locale: translation_locale }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when resource_type is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :edit, params: { resource_type: 'InvalidType', id: product.slug, translation_locale: translation_locale }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'PUT #update' do
    let(:product_params) do
      {
        "name_#{translation_locale}" => translated_name
      }
    end

    it 'updates the translation and sets flash success' do
      put :update, format: :turbo_stream, params: {
        resource_type: resource_type,
        id: product.slug,
        translation_locale: translation_locale,
        product: product_params
      }
      expect(response).to have_http_status(:ok)
      expect(flash.now[:success]).to be_present
      product.reload
      expect(product.send("name_#{translation_locale}")).to eq(translated_name)
    end

    context 'when resource_type is missing' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          put :update, format: :turbo_stream, params: {
            id: product.slug,
            resource_type: '',
            translation_locale: translation_locale,
            product: product_params
          }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when resource_type is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          put :update, format: :turbo_stream, params: {
            resource_type: 'InvalidType',
            id: product.slug,
            translation_locale: translation_locale,
            product: product_params
          }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
