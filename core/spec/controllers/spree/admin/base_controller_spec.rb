# Spree's rpsec controller tests get the Spree::ControllerHacks
# we don't need those for the anonymous controller here, so
# we call process directly instead of get
require 'spec_helper'

describe Spree::Admin::BaseController do

  controller(Spree::Admin::BaseController) do
    def index
      render :text => 'test'
    end
  end

  before do
    controller.stub :current_user => Factory(:admin_user)
  end

  describe "check alerts" do
    it "checks alerts with before_filter" do
      controller.should_receive :check_alerts
      process :index
    end

    it "saves alerts into session" do
      Spree::Alert.should_receive(:current).and_return([Spree::Alert.new(:message => "test alert", :severity => 'release')])
      process :index
      session[:alerts].first.message.should eq "test alert"
    end
  end
end
