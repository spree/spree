require 'spec_helper'

module Spree
  describe Api::V1::ZonesController do
    render_views

    let!(:attributes) { [:id, :name, :zone_members] }

    before do
      stub_authentication!
      @zone = create(:zone, :name => 'Europe')
    end

    it "gets list of zones" do
      api_get :index
      json_response.first.should have_attributes(attributes)
    end

    it "gets a zone" do
      api_get :show, :id => @zone.id
      json_response.should have_attributes(attributes)
      json_response['zone']['name'].should eq @zone.name
      json_response['zone']['zone_members'].size.should eq @zone.zone_members.count
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can create a new zone" do
        api_post :create, :zone => { :name => "North Pole",
                                     :zone_members => [ :zone_member => {
                                                        :zoneable_id => 1 }] }
        response.status.should == 201
        json_response.should have_attributes(attributes)
      end

      it "updates a zone" do
        api_put :update, :id => @zone.id,
                         :zone => { :name => "Americas",
                                    :zone_members => [ :zone_member => {
                                                       :zoneable_type => 'Spree::Country',
                                                       :zoneable_id => 1 }]}
        response.status.should == 200
        json_response['zone']['name'].should eq 'Americas'
      end

      it "can delete a zone" do
        api_delete :destroy, :id => @zone.id
        response.status.should == 204
        lambda { @zone.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
