require 'spec_helper'

describe 'alerts' do
  stub_authorization!

  controller(Spree::Admin::BaseController) do
    def index
      render :text => 'ok'
    end

    def should_check_alerts?
      true
    end
  end

  # Regression test for #3716
  it "alerts returned wrong data type" do
    get :index, {}
    response.body.should == 'ok'
  end
end