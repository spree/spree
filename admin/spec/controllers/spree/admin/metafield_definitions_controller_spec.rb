require 'spec_helper'

RSpec.describe Spree::Admin::MetafieldDefinitionsController, type: :controller do
  render_views
  stub_authorization!

  let(:metafield_definition) { create(:metafield_definition) }

  describe 'GET #index' do
    let!(:metafield_definitions) { create_list(:metafield_definition, 3) }

    it 'returns success' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @metafield_definitions' do
      get :index
      expect(assigns(:metafield_definitions)).to match_array(metafield_definitions)
    end

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end
  end

  describe 'GET #show' do
    it 'returns success' do
      get :show, params: { id: metafield_definition.id }
      expect(response).to be_successful
    end

    it 'assigns @metafield_definition' do
      get :show, params: { id: metafield_definition.id }
      expect(assigns(:metafield_definition)).to eq(metafield_definition)
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new @metafield_definition' do
      get :new
      expect(assigns(:metafield_definition)).to be_a_new(Spree::MetafieldDefinition)
    end

    it 'renders the new template' do
      get :new
      expect(response).to render_template(:new)
    end
  end

  describe 'GET #edit' do
    it 'returns success' do
      get :edit, params: { id: metafield_definition.id }
      expect(response).to be_successful
    end

    it 'assigns @metafield_definition' do
      get :edit, params: { id: metafield_definition.id }
      expect(assigns(:metafield_definition)).to eq(metafield_definition)
    end

    it 'renders the edit template' do
      get :edit, params: { id: metafield_definition.id }
      expect(response).to render_template(:edit)
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        key: 'test_field',
        name: 'Test Field',
        description: 'A test field',
        kind: 'short_text',
        resource_type: 'Spree::Product',
        display_on: 'both'
      }
    end

    let(:invalid_attributes) do
      {
        key: '',
        name: '',
        kind: 'invalid_kind'
      }
    end

    context 'with valid attributes' do
      it 'creates a new metafield definition' do
        expect {
          post :create, params: { metafield_definition: valid_attributes }
        }.to change(Spree::MetafieldDefinition, :count).by(1)
      end

      it 'redirects to the created metafield definition' do
        post :create, params: { metafield_definition: valid_attributes }
        expect(response).to redirect_to(admin_metafield_definition_path(assigns(:metafield_definition)))
      end

      it 'sets a success flash message' do
        post :create, params: { metafield_definition: valid_attributes }
        expect(flash[:success]).to be_present
      end
    end

    context 'with invalid attributes' do
      it 'does not create a new metafield definition' do
        expect {
          post :create, params: { metafield_definition: invalid_attributes }
        }.not_to change(Spree::MetafieldDefinition, :count)
      end

      it 'renders the new template' do
        post :create, params: { metafield_definition: invalid_attributes }
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PUT #update' do
    let(:new_attributes) do
      {
        name: 'Updated Field Name',
        description: 'Updated description'
      }
    end

    let(:invalid_attributes) do
      {
        key: '',
        name: ''
      }
    end

    context 'with valid attributes' do
      it 'updates the metafield definition' do
        put :update, params: { id: metafield_definition.id, metafield_definition: new_attributes }
        metafield_definition.reload
        expect(metafield_definition.name).to eq('Updated Field Name')
        expect(metafield_definition.description).to eq('Updated description')
      end

      it 'redirects to the metafield definition' do
        put :update, params: { id: metafield_definition.id, metafield_definition: new_attributes }
        expect(response).to redirect_to(admin_metafield_definition_path(metafield_definition))
      end

      it 'sets a success flash message' do
        put :update, params: { id: metafield_definition.id, metafield_definition: new_attributes }
        expect(flash[:success]).to be_present
      end
    end

    context 'with invalid attributes' do
      it 'does not update the metafield definition' do
        original_name = metafield_definition.name
        put :update, params: { id: metafield_definition.id, metafield_definition: invalid_attributes }
        metafield_definition.reload
        expect(metafield_definition.name).to eq(original_name)
      end

      it 'renders the edit template' do
        put :update, params: { id: metafield_definition.id, metafield_definition: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the metafield definition' do
      metafield_definition # create the record
      expect {
        delete :destroy, params: { id: metafield_definition.id }
      }.to change(Spree::MetafieldDefinition, :count).by(-1)
    end

    it 'redirects to the metafield definitions index' do
      delete :destroy, params: { id: metafield_definition.id }
      expect(response).to redirect_to(admin_metafield_definitions_path)
    end

    it 'sets a success flash message' do
      delete :destroy, params: { id: metafield_definition.id }
      expect(flash[:success]).to be_present
    end
  end

  describe 'permitted parameters' do
    it 'permits the correct attributes' do
      params = ActionController::Parameters.new(
        metafield_definition: {
          key: 'test',
          name: 'Test',
          description: 'Description',
          kind: 'short_text',
          resource_type: 'Spree::Product',
          display_on: 'both',
          forbidden_param: 'should not be permitted'
        }
      )

      controller.params = params
      permitted = controller.send(:permitted_resource_params)

      expect(permitted).to permit(:key, :name, :description, :kind, :resource_type, :display_on)
      expect(permitted).not_to permit(:forbidden_param)
    end
  end
end
