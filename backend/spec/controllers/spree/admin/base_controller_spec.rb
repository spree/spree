# Spree's rpsec controller tests get the Spree::ControllerHacks
# we don't need those for the anonymous controller here, so
# we call process directly instead of get
require 'spec_helper'

describe Spree::Admin::BaseController, type: :controller do
  controller(Spree::Admin::BaseController) do
    def index
      authorize! :update, Spree::Order
      render text: 'test'
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
end
