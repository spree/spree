require 'spec_helper'

module Spree
  describe Api::V1::CountriesController, :type => :controller do
    render_views

    before do
      stub_authentication!
      @state = create(:state)
      @country = @state.country
    end

    it "gets all countries" do
      api_get :index
      expect(json_response['countries'].first['iso3']).to eq @country.iso3
    end

    context "with two countries" do
      before { @zambia = create(:country, :name => "Zambia") }

      it "can view all countries" do
        api_get :index
        expect(json_response['count']).to eq(2)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(1)
      end

      it 'can query the results through a paramter' do
        api_get :index, :q => { :name_cont => 'zam' }
        expect(json_response['count']).to eq(1)
        expect(json_response['countries'].first['name']).to eq @zambia.name
      end

      it 'can control the page size through a parameter' do
        api_get :index, :per_page => 1
        expect(json_response['count']).to eq(1)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(2)
      end
    end

    it "includes states" do
      api_get :show, :id => @country.id
      states = json_response['states']
      expect(states.first['name']).to eq @state.name
    end
  end
end
