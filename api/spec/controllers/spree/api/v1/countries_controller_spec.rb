require 'spec_helper'

module Spree
  describe Api::V1::CountriesController do
    render_views

    before do
      stub_authentication!
      @state = create(:state)
      @country = @state.country
    end

    it "gets all countries" do
      api_get :index
      json_response["countries"].first['country']['iso3'].should eq @country.iso3
    end

    context "with two countries" do
      before { @zambia = create(:country, :name => "Zambia") }

      it "can view all countries" do
        api_get :index
        json_response['count'].should == 2
        json_response['current_page'].should == 1
        json_response['pages'].should == 1
      end

      it 'can query the results through a paramter' do
        api_get :index, :q => { :name_cont => 'zam' }
        json_response['count'].should == 1
        json_response['countries'].first['country']['name'].should eq @zambia.name
      end

      it 'can control the page size through a parameter' do
        api_get :index, :per_page => 1
        json_response['count'].should == 1
        json_response['current_page'].should == 1
        json_response['pages'].should == 2
      end
    end

    it "includes states" do
      api_get :show, :id => @country.id
      states = json_response['country']['states']
      states.first['state']['name'].should eq @state.name
    end
  end
end
