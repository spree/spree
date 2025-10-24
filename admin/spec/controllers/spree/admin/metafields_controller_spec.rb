require 'spec_helper'

RSpec.describe Spree::Admin::MetafieldsController, type: :controller do
  stub_authorization!
  render_views

  let(:product) { create(:product) }
  let!(:metafield_definition) { create(:metafield_definition, resource_type: 'Spree::Product') }
  let(:resource_type) { 'Spree::Product' }

  describe 'GET #edit' do
    it 'assigns @object and @metafields and renders the edit template' do
      get :edit, params: { resource_type: resource_type, id: product.id }
      expect(response).to render_template(:edit)
      expect(assigns(:object)).to eq(product)
      expect(assigns(:metafields)).to be_present
      expect(assigns(:metafields).map(&:metafield_definition)).to include(metafield_definition)
      expect(assigns(:metafields).first.value).to be_blank
      expect(assigns(:metafields).first.type).to eq(metafield_definition.metafield_type)
      expect(assigns(:metafields).first.metafield_definition).to eq(metafield_definition)
      expect(assigns(:metafields).first.id).to be_blank
      expect(assigns(:metafield_definitions)).to include(metafield_definition)
    end

    context 'with existing metafields' do
      let!(:metafield_definition_2) { create(:metafield_definition, resource_type: 'Spree::Product') }
      let!(:metafield) { create(:metafield, resource: product, metafield_definition: metafield_definition) }

      it 'assigns @resource and @metafields and renders the edit template' do
        get :edit, params: { resource_type: resource_type, id: product.id }
        expect(response).to render_template(:edit)
        expect(assigns(:object)).to eq(product)
        expect(assigns(:metafields)).to be_present
        expect(assigns(:metafields).map(&:metafield_definition)).to contain_exactly(metafield_definition, metafield_definition_2)
        expect(assigns(:metafields).map(&:value)).to contain_exactly(metafield.value, nil)
        expect(assigns(:metafields).map(&:type)).to contain_exactly(metafield_definition.metafield_type, metafield_definition_2.metafield_type)
        expect(assigns(:metafields).map(&:metafield_definition)).to contain_exactly(metafield_definition, metafield_definition_2)
        expect(assigns(:metafields).map(&:id)).to contain_exactly(metafield.id, nil)
      end
    end

    context 'when resource_type is missing' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :edit, params: { id: product.id, resource_type: '' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when resource_type is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :edit, params: { resource_type: 'InvalidType', id: product.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'PUT #update' do
    let!(:metafield) { create(:metafield, resource: product, metafield_definition: metafield_definition) }
    let!(:metafield_definition_2) { create(:metafield_definition, :rich_text_field, resource_type: 'Spree::Product') }
    let!(:metafield_definition_3) { create(:metafield_definition, :boolean_field, resource_type: 'Spree::Product') }

    let(:metafield_attributes) do
      {
        metafields_attributes: {
          "0" => {
            id: metafield.id,
            type: metafield_definition.metafield_type,
            metafield_definition_id: metafield_definition.id,
            value: 'Test Value'
          },
          "1" => {
            id: nil,
            type: metafield_definition_2.metafield_type,
            metafield_definition_id: metafield_definition_2.id,
            value: '<strong>Test Value</strong>'
          },
          "2" => {
            id: nil,
            type: metafield_definition_3.metafield_type,
            metafield_definition_id: metafield_definition_3.id,
            value: '0'
          }
        }
      }
    end

    it 'updates metafields and sets flash success' do
      put :update, format: :turbo_stream, params: {
        resource_type: resource_type,
        id: product.id,
        product: metafield_attributes
      }
      expect(response).to have_http_status(:ok)
      expect(flash.now[:success]).to be_present
      product.reload

      metafield = product.metafields.find_by(metafield_definition_id: metafield_definition.id)
      expect(metafield.value).to eq('Test Value')

      metafield2 = product.metafields.find_by(metafield_definition_id: metafield_definition_2.id)
      expect(metafield2.value).to be_kind_of(ActionText::RichText)
      expect(metafield2.value.to_s).to include('<strong>Test Value</strong>')

      metafield3 = product.metafields.find_by(metafield_definition_id: metafield_definition_3.id)
      expect(metafield3.value).to eq('false')
    end

    context 'when resource_type is missing' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          put :update, format: :turbo_stream, params: { id: product.id, resource_type: '', product: metafield_attributes }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when resource_type is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          put :update, format: :turbo_stream, params: { resource_type: 'InvalidType', id: product.id, product: metafield_attributes }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
