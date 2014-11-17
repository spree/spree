require 'spec_helper'

describe Spree::Api::StoreCreditEventsController do
  render_views

  stub_api_controller_authentication!

  describe "GET mine" do

    subject { spree_get :mine, { format: :json } }

    before { controller.stub(current_api_user: current_api_user) }

    context "the current api user is not persisted" do
      let(:current_api_user) { double(persisted?: false) }

      before { subject }

      it "returns a 401" do
        response.status.should eq 401
      end
    end

    context "the current api user is authenticated" do
      let(:current_api_user) { order.user }
      let(:order) { create(:order, line_items: [line_item]) }

      context "the user doesn't have store credit" do
        let(:current_api_user) { create(:user) }

        before { subject }

        it "should set the events variable to empty list" do
          assigns(:store_credit_events).should eq []
        end

        it "returns a 200" do
          subject.status.should eq 200
        end
      end

      context "the user has store credit" do
        let(:store_credit)     { create(:store_credit, user: api_user) }
        let(:current_api_user) { store_credit.user }

        before { subject }

        it "should contain one store credit event" do
          assigns(:store_credit_events).size.should eq 1
        end

        it "should contain the store credit allocation event" do
          assigns(:store_credit_events).first.should eq store_credit.store_credit_events.first
        end

        it "returns a 200" do
          subject.status.should eq 200
        end
      end
    end
  end
end
