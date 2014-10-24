require 'spec_helper'

describe 'alerts', :type => :controller do
  stub_authorization!

  controller(Spree::Admin::BaseController) do
    def index
      render :text => 'ok'
    end

    def should_check_alerts?
      true
    end
  end

  before do
    # Spree::Alert.should_receive(:current).and_return("string")
  end

  # Regression test for #3716
  it "alerts returned wrong data type" do
    get :index, {}
    expect(response.body).to eq('ok')
  end
end