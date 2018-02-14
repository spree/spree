require 'spec_helper'

module Spree
  describe Api::V1::OptionTypesController, type: :controller do
    render_views

    let(:attributes) { [:id, :name, :presentation, :position] }
    let!(:option_value) { create(:option_value) }
    let!(:option_type) { option_value.option_type }

    before do
      stub_authentication!
    end

    def check_option_values(option_values)
      expect(option_values.count).to eq(1)
      expect(option_values.first).to have_attributes([:id, :name, :presentation,
                                                      :option_type_id, :option_type_name])
    end

    it 'can list all option types' do
      api_get :index
      expect(json_response.count).to eq(1)
      expect(json_response.first).to have_attributes(attributes)

      check_option_values(json_response.first['option_values'])
    end

    it 'can search for an option type' do
      create(:option_type, name: 'buzz')
      api_get :index, q: { name_cont: option_type.name }
      expect(json_response.count).to eq(1)
      expect(json_response.first).to have_attributes(attributes)
    end

    it 'can retrieve a list of specific option types' do
      option_type_1 = create(:option_type)
      create(:option_type) # option_type_2

      api_get :index, ids: "#{option_type.id},#{option_type_1.id}"
      expect(json_response.count).to eq(2)

      check_option_values(json_response.first['option_values'])
    end

    it 'can list a single option type' do
      api_get :show, id: option_type.id
      expect(json_response).to have_attributes(attributes)
      check_option_values(json_response['option_values'])
    end

    it 'can learn how to create a new option type' do
      api_get :new
      expect(json_response['attributes']).to eq(attributes.map(&:to_s))
      expect(json_response['required_attributes']).not_to be_empty
    end

    it 'cannot create a new option type' do
      api_post :create, option_type: {
        name: 'Option Type',
        presentation: 'Option Type'
      }
      assert_unauthorized!
    end

    it 'cannot alter an option type' do
      original_name = option_type.name
      api_put :update, id: option_type.id,
                       option_type: {
                         name: 'Option Type'
                       }
      assert_not_found!
      expect(option_type.reload.name).to eq(original_name)
    end

    it 'cannot delete an option type' do
      api_delete :destroy, id: option_type.id
      assert_not_found!
      expect { option_type.reload }.not_to raise_error
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'can create an option type' do
        api_post :create, option_type: {
          name: 'Option Type',
          presentation: 'Option Type'
        }
        expect(json_response).to have_attributes(attributes)
        expect(response.status).to eq(201)
      end

      it 'cannot create an option type with invalid attributes' do
        api_post :create, option_type: {}
        expect(response.status).to eq(422)
      end

      it 'can update an option type' do
        api_put :update, id: option_type.id, option_type: { name: 'Option Type' }
        expect(response.status).to eq(200)
        expect(option_type.reload.name).to eq('Option Type')
      end

      it 'cannot update an option type with invalid attributes' do
        api_put :update, id: option_type.id, option_type: { name: '' }
        expect(response.status).to eq(422)
      end

      it 'can delete an option type' do
        api_delete :destroy, id: option_type.id
        expect(response.status).to eq(204)
      end
    end
  end
end
