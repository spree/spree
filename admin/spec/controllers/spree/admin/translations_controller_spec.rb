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
    it 'assigns @object and renders the edit template' do
      get :edit, params: { resource_type: resource_type, id: product.id, translation_locale: translation_locale }
      expect(response).to render_template(:edit)
      expect(assigns(:object)).to eq(product)
      expect(assigns(:locales)).to include('fr')
      expect(assigns(:locales)).not_to include('en')
    end

    context 'when resource_type is missing' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :edit, params: { id: product.id, resource_type: '', translation_locale: translation_locale }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when resource_type is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :edit, params: { resource_type: 'InvalidType', id: product.id, translation_locale: translation_locale }
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
        id: product.id,
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
            id: product.id,
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
            id: product.id,
            translation_locale: translation_locale,
            product: product_params
          }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'Spree::Admin::TranslationsController translation_fields and normalized_locale' do
    let(:controller_instance) { described_class.new }
    let(:product_class) { Spree::Product }

    describe '#normalized_locale' do
      it 'converts en-GB to en_gb' do
        expect(controller_instance.normalized_locale('en-GB')).to eq('en_gb')
      end

      it 'converts fr to fr' do
        expect(controller_instance.normalized_locale('fr')).to eq('fr')
      end
    end

    describe '#translation_fields' do
      before do
        controller_instance.instance_variable_set(:@selected_translation_locale, 'en_gb')
        allow(product_class).to receive(:translatable_fields).and_return(['name', 'description'])
      end

      it 'returns fields with normalized locale suffix' do
        fields = controller_instance.send(:translation_fields, product_class)
        expect(fields).to eq(['name_en_gb', 'description_en_gb'])
      end
    end
  end

end
