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
      Spree::Admin::BaseController.any_instance.stub(:spree_current_user).and_return(nil)
    end

    it "redirects to root" do
      controller.stub_chain(:spree, :root_path).and_return('/root')
      get :index
      expect(response).to redirect_to '/root'
    end
  end
end
