require 'spec_helper'

RSpec.describe Spree::Admin::MetafieldDefinitionsController, type: :controller do
  stub_authorization!
  render_views

  let!(:metafield_definition) { create(:metafield_definition) }
  let(:valid_attributes) do
    {
      name: 'External ID',
      namespace: 'external',
      key: 'id',
      metafield_type: 'Spree::Metafields::ShortText',
      resource_type: 'Spree::Product'
    }
  end

  let(:invalid_attributes) do
    {
      name: '',
      namespace: '',
      key: '',
      metafield_type: '',
      resource_type: ''
    }
  end

  describe 'GET #index' do
    let!(:metafield_definitions) { create_list(:metafield_definition, 3) }
    let!(:taxon_rich_text_field) { create(:metafield_definition, :rich_text_field, resource_type: 'Spree::Taxon') }

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
      expect(assigns[:collection]).to include(*metafield_definitions)
      expect(assigns[:collection]).to include(taxon_rich_text_field)
    end

    context 'filtering by resource type' do
      it 'renders the index template' do
        get :index, params: { q: { resource_type_eq: 'Spree::Taxon' } }
        expect(response).to render_template(:index)
        expect(assigns[:collection]).to eq([taxon_rich_text_field])
      end
    end
  end

  describe 'GET #new' do
    it 'renders the new template' do
      get :new, params: { resource_type: 'Spree::Product' }
      expect(response).to render_template(:new)
      expect(assigns(:object)).to be_a(Spree::MetafieldDefinition)
      expect(assigns(:object).resource_type).to eq('Spree::Product')
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new MetafieldDefinition and redirects' do
        expect {
          post :create, params: { metafield_definition: valid_attributes }
        }.to change(Spree::MetafieldDefinition, :count).by(1)
        expect(response).to redirect_to(spree.admin_metafield_definitions_path)
        expect(flash[:success]).to be_present
      end
    end

    context 'with invalid params' do
      it 'does not create a new MetafieldDefinition and re-renders new' do
        expect {
          post :create, params: { metafield_definition: invalid_attributes }
        }.not_to change(Spree::MetafieldDefinition, :count)
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #edit' do
    it 'renders the edit template' do
      get :edit, params: { id: metafield_definition.id }
      expect(response).to render_template(:edit)
      expect(assigns(:object)).to eq(metafield_definition)
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      it 'updates the MetafieldDefinition and redirects' do
        put :update, params: { id: metafield_definition.id, metafield_definition: { name: 'Size' } }
        expect(response).to redirect_to(spree.admin_metafield_definitions_path)
        expect(assigns(:object).reload.name).to eq('Size')
        expect(flash[:success]).to be_present
      end
    end

    context 'with invalid params' do
      it 'does not update and re-renders edit' do
        put :update, params: { id: metafield_definition.id, metafield_definition: { name: '' } }
        expect(response).to render_template(:edit)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assigns(:object).reload.name).not_to eq('')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the MetafieldDefinition and redirects' do
      metafield = create(:metafield_definition, :short_text_field)
      expect {
        delete :destroy, params: { id: metafield.id }
      }.to change(Spree::MetafieldDefinition, :count).by(-1)
      expect(response).to redirect_to(spree.admin_metafield_definitions_path)
      expect(flash[:success]).to be_present
    end
  end
end
