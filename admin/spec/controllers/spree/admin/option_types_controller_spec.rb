require 'spec_helper'

describe Spree::Admin::OptionTypesController, type: :controller do
  stub_authorization!

  render_views

  describe '#index' do
    let!(:option_type) { create(:option_type) }

    it 'responds successfully' do
      get :index
      expect(response).to be_successful
    end
  end

  describe '#new' do
    it 'responds successfully' do
      get :new
      expect(response).to be_successful
    end
  end

  describe '#create' do
    let(:params) do
      {
        option_type: {
          name: 'test-option-type',
          presentation: 'Test Option Type',
          option_values_attributes: [
            {
              name: 'test-option-value',
              presentation: 'Test Option Value'
            }
          ]
        }
      }
    end

    it 'creates a new option type' do
      expect {
        post :create, params: params
      }.to change(Spree::OptionType, :count).by(1).and change(Spree::OptionValue, :count).by(1)
    end

    it 'sets the attributes' do
      post :create, params: params
      option_type = Spree::OptionType.last
      expect(option_type.name).to eq('test-option-type')
      expect(option_type.presentation).to eq('Test Option Type')
      expect(option_type.option_values.first.name).to eq('test-option-value')
    end

    it 'redirects to edit with success flash' do
      post :create, params: params
      expect(response).to redirect_to(spree.edit_admin_option_type_path(Spree::OptionType.last))
      expect(flash[:success]).to be_present
    end
  end

  describe '#edit' do
    let!(:option_type) { create(:option_type) }

    it 'responds successfully' do
      get :edit, params: { id: option_type.id }
      expect(response).to be_successful
    end

    it 'builds a new option value if none exist' do
      get :edit, params: { id: option_type.id }
      expect(assigns(:option_type).option_values.select(&:new_record?).count).to eq(1)
    end
  end

  describe '#update' do
    let!(:option_type) { create(:option_type, filterable: false) }
    let!(:option_value) { create(:option_value, option_type: option_type, position: 1) }
    let(:params) do
      {
        id: option_type.id,
        option_type: {
          name: 'updated-name',
          presentation: 'Updated Name',
          position: 3,
          filterable: true,
          option_values_attributes: [
            {
              id: option_value.id,
              name: 'updated-option-value',
              presentation: 'Updated Option Value',
              position: 2
            },
            {
              name: 'new-option-value',
              presentation: 'New Option Value',
              position: 1
            }
          ]
        }
      }
    end

    it 'updates the option type and option value' do
      put :update, params: params
      option_type.reload
      expect(option_type.name).to eq('updated-name')
      expect(option_type.presentation).to eq('Updated Name')
      expect(option_type.position).to eq(3)
      expect(option_type.filterable).to be_truthy
      expect(option_type.option_values.count).to eq(2)
      expect(option_type.option_values.first.name).to eq('new-option-value')
      expect(option_type.option_values.last.name).to eq('updated-option-value')
    end

    it 'redirects to edit with success flash' do
      put :update, params: params
      expect(response).to redirect_to(spree.edit_admin_option_type_path(option_type))
      expect(flash[:success]).to be_present
    end
  end

  describe '#destroy' do
    let!(:option_type) { create(:option_type) }

    it 'destroys the option type' do
      expect {
        delete :destroy, params: { id: option_type.id }
      }.to change(Spree::OptionType, :count).by(-1)
    end

    it 'redirects to index with success flash' do
      delete :destroy, params: { id: option_type.id }
      expect(response).to redirect_to(spree.admin_option_types_path)
      expect(flash[:success]).to be_present
    end
  end
end
