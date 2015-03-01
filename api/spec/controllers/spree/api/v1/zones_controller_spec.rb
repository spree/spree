require 'spec_helper'

module Spree
  describe Api::V1::ZonesController, :type => :controller do
    render_views

    let!(:attributes) { [:id, :name, :zone_members] }

    before do
      stub_authentication!
      @zone = create(:zone, :name => 'Europe')
    end

    it "gets list of zones" do
      api_get :index
      expect(json_response['zones'].first).to have_attributes(attributes)
    end

    it 'can control the page size through a parameter' do
      create(:zone)
      api_get :index, :per_page => 1
      expect(json_response['count']).to eq(1)
      expect(json_response['current_page']).to eq(1)
      expect(json_response['pages']).to eq(2)
    end

    it 'can query the results through a paramter' do
      expected_result = create(:zone, :name => 'South America')
      api_get :index, :q => { :name_cont => 'south' }
      expect(json_response['count']).to eq(1)
      expect(json_response['zones'].first['name']).to eq expected_result.name
    end

    it "gets a zone" do
      api_get :show, :id => @zone.id
      expect(json_response).to have_attributes(attributes)
      expect(json_response['name']).to eq @zone.name
      expect(json_response['zone_members'].size).to eq @zone.zone_members.count
    end

    context "specifying a rabl template to use" do
      before do
        described_class.class_eval do
          def custom_show
            respond_with(zone)
          end
        end
      end

      it "uses the specified template" do
        @routes = ActionDispatch::Routing::RouteSet.new.tap do |r|
          r.draw { get 'custom_show' => 'spree/api/v1/zones#custom_show' }
        end

        request.headers['X-Spree-Template'] = 'show'
        api_get :custom_show, :id => @zone.id
        expect(response).to render_template('spree/api/v1/zones/show')
      end

      it "falls back to the default template if the specified template does not exist" do
        request.headers['X-Spree-Template'] = 'invoice'
        api_get :show, :id => @zone.id
        expect(response).to render_template('spree/api/v1/zones/show')
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can create a new zone" do
        params = {
          :zone => {
            :name => "North Pole",
            :zone_members => [
              {
                :zoneable_type => "Spree::Country",
                :zoneable_id => 1
              }
            ]
          }
        }

        api_post :create, params
        expect(response.status).to eq(201)
        expect(json_response).to have_attributes(attributes)
        expect(json_response["zone_members"]).not_to be_empty
      end

      it "updates a zone" do
        params = { :id => @zone.id,
          :zone => {
            :name => "North Pole",
            :zone_members => [
              {
                :zoneable_type => "Spree::Country",
                :zoneable_id => 1
              }
            ]
          }
        }

        api_put :update, params
        expect(response.status).to eq(200)
        expect(json_response['name']).to eq 'North Pole'
        expect(json_response['zone_members']).not_to be_blank
      end

      it "can delete a zone" do
        api_delete :destroy, :id => @zone.id
        expect(response.status).to eq(204)
        expect { @zone.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
