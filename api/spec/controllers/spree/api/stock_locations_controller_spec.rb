require 'spec_helper'

module Spree
  describe Api::StockLocationsController do
    render_views

    let!(:stock_location) { create(:stock_location) }
    let!(:attributes) { [:id, :name, :address1, :address2, :city, :state_id, :state_name, :country_id, :zipcode, :phone, :active] }

    before do
      stub_authentication!
    end

    context "as a user" do
      it "cannot see stock locations" do
        api_get :index
        response.status.should == 401
      end

      it "cannot see a single stock location" do
        api_get :show, :id => stock_location.id
        response.status.should == 401
      end

      it "cannot create a new stock location" do
        params = {
          stock_location: {
            name: "North Pole",
            active: true
          }
        }

        api_post :create, params
        response.status.should == 401
      end

      it "cannot update a stock location" do
        api_put :update, :stock_location => { :name => "South Pole" }, :id => stock_location.to_param
        response.status.should == 401
      end

      it "cannot delete a stock location" do
        api_put :destroy, :id => stock_location.to_param
        response.status.should == 401
      end
    end

    
    context "as an admin" do
      sign_in_as_admin!

      it "gets list of stock locations" do
        api_get :index
        json_response['stock_locations'].first.should have_attributes(attributes)
        json_response['stock_locations'].first['country'].should_not be_nil
        json_response['stock_locations'].first['state'].should_not be_nil
      end

      it 'can control the page size through a parameter' do
        create(:stock_location)
        api_get :index, per_page: 1
        json_response['count'].should == 1
        json_response['current_page'].should == 1
        json_response['pages'].should == 2
      end

      it 'can query the results through a paramter' do
        expected_result = create(:stock_location, name: 'South America')
        api_get :index, q: { name_cont: 'south' }
        json_response['count'].should == 1
        json_response['stock_locations'].first['name'].should eq expected_result.name
      end

      it "gets a stock location" do
        api_get :show, id: stock_location.to_param
        json_response.should have_attributes(attributes)
        json_response['name'].should eq stock_location.name
      end

      it "can create a new stock location" do
        params = {
          stock_location: {
            name: "North Pole",
            active: true
          }
        }

        api_post :create, params
        response.status.should == 201
        json_response.should have_attributes(attributes)
      end

      it "can update a stock location" do
        params = {
          id: stock_location.to_param,
          stock_location: {
            name: "South Pole"
          }
        }

        api_put :update, params
        response.status.should == 200
        json_response['name'].should eq 'South Pole'
      end

      it "can delete a stock location" do
        api_delete :destroy, id: stock_location.to_param
        response.status.should == 204
        lambda { stock_location.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
