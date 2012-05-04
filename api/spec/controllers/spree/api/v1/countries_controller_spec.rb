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
      json_response.first['country']['iso3'].should eq @country.iso3
    end

    it "includes states" do
      api_get :show, :id => @country.id
      states = json_response['country']['states']
      states.first['state']['name'].should eq @state.name
    end
  end
end
