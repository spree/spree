# Spree's rpsec controller tests get the Spree::ControllerHacks
# we don't need those for the anonymous controller here, so
# we call process directly instead of get
require 'spec_helper'

describe Spree::Admin::BaseController, :type => :controller do
  controller(Spree::Admin::BaseController) do
    def index
      authorize! :update, Spree::Order
      render :text => 'test'
    end
  end

  context "unauthorized request" do
    before do
      allow_any_instance_of(Spree::Admin::BaseController).to receive(:spree_current_user).and_return(nil)
    end

    it "redirects to root" do
      allow(controller).to receive_message_chain(:spree, :root_path).and_return('/root')
      get :index
      expect(response).to redirect_to '/root'
    end
  end

  describe "check alerts" do
    stub_authorization!

    it "checks alerts with before_filter" do
      expect(controller).to receive :check_alerts
      process :index
    end

    it "saves alerts into session" do
      allow(controller).to receive_messages(:should_check_alerts? => true)
      expect(Spree::Alert).to receive(:current).and_return([{"id" => "1", "message" => "test alert", "severity" => 'release'}])
      process :index
      expect(session[:alerts].first["message"]).to eq "test alert"
    end

    describe "should_check_alerts?" do
      before do
        allow(Rails.env).to receive_messages(:production? => true)
        Spree::Config[:check_for_spree_alerts] = true
        Spree::Config[:last_check_for_spree_alerts] = nil
      end

      it "only checks alerts if production and preference is true" do
        expect(controller.send(:should_check_alerts?)).to be true
      end

      it "only checks for production" do
        allow(Rails.env).to receive_messages(:production? => false)
        expect(controller.send(:should_check_alerts?)).to be false
      end

      it "only checks if preference is true" do
        Spree::Config[:check_for_spree_alerts] = false
        expect(controller.send(:should_check_alerts?)).to be false
      end
    end
  end

  context "#generate_api_key" do
    let(:user) { mock_model(Spree.user_class) }

    before do
      allow(controller).to receive(:authorize_admin) { true }
      allow(controller).to receive(:try_spree_current_user) { user }
    end

    it "generates the API key for a user when they visit" do
      expect(user).to receive(:spree_api_key).and_return(nil)
      expect(user).to receive(:generate_spree_api_key!)
      get :index
    end

    it "does not attempt to regenerate the API key if the key is already set" do
      expect(user).to receive(:spree_api_key).and_return('fake')
      expect(user).not_to receive(:generate_spree_api_key!)
      get :index
    end
  end
end
