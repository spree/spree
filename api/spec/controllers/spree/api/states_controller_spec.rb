require 'spec_helper'

module Spree
  describe Api::StatesController do
    render_views

    let!(:state) { create(:state, :name => "Victoria") }
    let(:attributes) { [:id, :name, :abbr, :country_id] }

    before do
      stub_authentication!
    end

    it "gets all countries" do
      api_get :index
      json_response["states"].first.should have_attributes(attributes)
      json_response['states'].first['name'].should eq(state.name)
    end

    context "with two countries" do
      before { create(:state, :name => "New South Wales") }

      it "gets all states for a country" do
        country = create(:country)
        state.country = country 
        state.save

        api_get :index, :country_id => country.id
        json_response["states"].first.should have_attributes(attributes)
        json_response["states"].count.should == 1
      end

      it "can view all countries" do
        api_get :index
        json_response["states"].first.should have_attributes(attributes)
        json_response['count'].should == 2
        json_response['current_page'].should == 1
        json_response['pages'].should == 1
      end

      it 'can query the results through a paramter' do
        api_get :index, :q => { :name_cont => 'Vic' }
        json_response['count'].should == 1
        json_response['states'].first['name'].should eq("Victoria")
      end

      it 'can control the page size through a parameter' do
        api_get :index, :per_page => 1
        json_response['count'].should == 1
        json_response['current_page'].should == 1
        json_response['pages'].should == 2
      end
    end

    it "can view a state" do
      api_get :show, :id => state.id
      json_response.should have_attributes(attributes)
    end
  end
end
