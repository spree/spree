require 'spec_helper'

module Spree
  describe Api::V1::OptionValuesController, :type => :controller do
    render_views

    let(:attributes) { [:id, :name, :presentation, :option_type_name, :option_type_name] }
    let!(:option_value) { create(:option_value) }
    let!(:option_type) { option_value.option_type }

    before do
      stub_authentication!
    end

    def check_option_values(option_values)
      expect(option_values.count).to eq(1)
      expect(option_values.first).to have_attributes([:id, :name, :presentation,
                                                  :option_type_name, :option_type_id])
    end

    context "without any option type scoping" do
      before do
        # Create another option value with a brand new option type
        create(:option_value, :option_type => create(:option_type))
      end

      it "can retrieve a list of all option values" do
        api_get :index
        expect(json_response.count).to eq(2)
        expect(json_response.first).to have_attributes(attributes)
      end
    end

    context "for a particular option type" do
      let(:resource_scoping) { { :option_type_id => option_type.id } }

      it "can list all option values" do
        api_get :index
        expect(json_response.count).to eq(1)
        expect(json_response.first).to have_attributes(attributes)
      end

      it "can search for an option type" do
        create(:option_value, :name => "buzz")
        api_get :index, :q => { :name_cont => option_value.name }
        expect(json_response.count).to eq(1)
        expect(json_response.first).to have_attributes(attributes)
      end

      it "can retrieve a list of option types" do
        option_value_1 = create(:option_value, :option_type => option_type)
        option_value_2 = create(:option_value, :option_type => option_type)
        api_get :index, :ids => [option_value.id, option_value_1.id]
        expect(json_response.count).to eq(2)
      end

      it "can list a single option value" do
        api_get :show, :id => option_value.id
        expect(json_response).to have_attributes(attributes)
      end

      it "cannot create a new option value" do
        api_post :create, :option_value => {
                          :name => "Option Value",
                          :presentation => "Option Value"
                        }
        assert_unauthorized!
      end

      it "cannot alter an option value" do
        original_name = option_type.name
        api_put :update, :id => option_type.id,
                          :option_value => {
                            :name => "Option Value"
                          }
        assert_not_found!
        expect(option_type.reload.name).to eq(original_name)
      end

      it "cannot delete an option value" do
        api_delete :destroy, :id => option_type.id
        assert_not_found!
        expect { option_type.reload }.not_to raise_error
      end

      context "as an admin" do
        sign_in_as_admin!

        it "can create an option value" do
          api_post :create, :option_value => {
                            :name => "Option Value",
                            :presentation => "Option Value"
                          }
          expect(json_response).to have_attributes(attributes)
          expect(response.status).to eq(201)
        end

        it "cannot create an option type with invalid attributes" do
          api_post :create, :option_value => {}
          expect(response.status).to eq(422)
        end

        it "can update an option value" do
          original_name = option_value.name
          api_put :update, :id => option_value.id, :option_value => {
                                :name => "Option Value",
                              }
          expect(response.status).to eq(200)

          option_value.reload
          expect(option_value.name).to eq("Option Value")
        end

        it "permits the correct attributes" do
          expect(controller).to receive(:permitted_option_value_attributes)
          api_put :update, :id => option_value.id, :option_value => {
                            :name => ""
                           }
        end

        it "cannot update an option value with invalid attributes" do
          api_put :update, :id => option_value.id, :option_value => {
                            :name => ""
                           }
          expect(response.status).to eq(422)
        end

        it "can delete an option value" do
          api_delete :destroy, :id => option_value.id
          expect(response.status).to eq(204)
        end
      end
    end
  end
end
