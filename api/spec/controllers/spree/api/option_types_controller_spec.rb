require 'spec_helper'

module Spree
  describe Api::OptionTypesController do
    render_views

    let(:attributes) { [:id, :name, :position, :presentation] }
    let!(:option_value) { create(:option_value) }
    let!(:option_type) { option_value.option_type }

    before do
      stub_authentication!
    end

    def check_option_values(option_values)
      option_values.count.should == 1
      option_values.first.should have_attributes([:id, :name, :presentation,
                                                  :option_type_name, :option_type_id])
    end

    it "can list all option types" do
      api_get :index
      json_response.count.should == 1
      json_response.first.should have_attributes(attributes)

      check_option_values(json_response.first["option_values"])
    end

    it "can search for an option type" do
      create(:option_type, :name => "buzz")
      api_get :index, :q => { :name_cont => option_type.name }
      json_response.count.should == 1
      json_response.first.should have_attributes(attributes)
    end

    it "can retreive a list of specific option types" do
      option_type_1 = create(:option_type)
      option_type_2 = create(:option_type)
      api_get :index, :ids => "#{option_type.id},#{option_type_1.id}"
      json_response.count.should == 2

      check_option_values(json_response.first["option_values"])
    end

    it "can list a single option type" do
      api_get :show, :id => option_type.id
      json_response.should have_attributes(attributes)
      check_option_values(json_response["option_values"])
    end

    it "cannot create a new option type" do
      api_post :create, :option_type => {
                        :name => "Option Type",
                        :presentation => "Option Type"
                      }
      assert_unauthorized!
    end

    it "cannot alter an option type" do
      original_name = option_type.name
      api_put :update, :id => option_type.id,
                        :option_type => {
                          :name => "Option Type"
                        }
      assert_unauthorized!
      option_type.reload.name.should == original_name
    end

    it "cannot delete an option type" do
      api_delete :destroy, :id => option_type.id
      assert_unauthorized!
      lambda { option_type.reload }.should_not raise_error
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can create an option type" do
        api_post :create, :option_type => {
                          :name => "Option Type",
                          :presentation => "Option Type"
                        }
        json_response.should have_attributes(attributes)
        response.status.should == 201
      end

      it "cannot create an option type with invalid attributes" do
        api_post :create, :option_type => {}
        response.status.should == 422
      end

      it "can update an option type" do
        original_name = option_type.name
        api_put :update, :id => option_type.id, :option_type => {
                              :name => "Option Type",
                            }
        response.status.should == 200

        option_type.reload
        option_type.name.should == "Option Type"
      end

      it "cannot update an option type with invalid attributes" do
        api_put :update, :id => option_type.id, :option_type => {
                          :name => ""
                         }
        response.status.should == 422
      end

      it "can delete an option type" do
        api_delete :destroy, :id => option_type.id
        response.status.should == 204
      end
    end
  end
end
