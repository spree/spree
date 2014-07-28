require 'spec_helper'

module Spree
  describe Api::CreditCardsController do
    render_views

    let!(:card) { create(:credit_card) }

    let(:current_api_user) do
      user = Spree.user_class.new(:email => "spree@example.com")
      user.generate_spree_api_key!
      user
    end
    
    before do
      stub_authentication!
    end
    
    it "the user id doesn't exist" do
      api_get :index, user_id: 1000
	  
	  response.status.should == 404
	end
	
	context "user does not have a credit card" do
      let(:current_api_user) do
        user = Spree.user_class.new(:email => "spree2@example.com", :id => 2)
        user.generate_spree_api_key!
        user
      end

      it "can not view any credit cards" do
        api_get :index, user_id: current_api_user.id

        response.status.should == 200
        json_response["pages"].should == 0
      end
    end
    
	context "user has a credit card " do
      let!(:card) { create(:credit_card, user_id: current_api_user.id, gateway_customer_profile_id: "random") }

      it "can view all of their own credit cards" do
        api_get :index, user_id: current_api_user.id

        response.status.should == 200
        json_response["pages"].should == 1
        json_response["current_page"].should == 1
        json_response["credit_cards"].length.should == 1
        json_response["credit_cards"].first["id"].should == card.id
      end
    end
  end
end
