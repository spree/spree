require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::BaseController do

  describe "Spree Alert Checks" do
    it "only checks once per session" do
      controller.stub(:current_user => true)
      Spree::Config.set :check_for_spree_alerts => true
      session[:alerts] = []
      Spree::Alert.should_not_receive(:current)
      controller.send(:check_alerts)
    end

    it "does not check if preference is false" do
      controller.stub(:current_user => true)
      Spree::Config.set :check_for_spree_alerts => false
      controller.send(:check_alerts)
      session[:alerts].should be_nil
    end

    it "checks alerts if preference is true" do
      controller.stub(:current_user => true)
      Spree::Config.set :check_for_spree_alerts => true
      alerts = []
      Spree::Alert.should_receive(:current).and_return(alerts)
      controller.send(:check_alerts)
      session[:alerts].should eq alerts
      Spree::Config[:last_check_for_spree_alerts].should_not be_nil
    end

    it "filters alerts stored in preferences" do
      Spree::Config.set :dismissed_spree_alerts => "1,3"
      alerts = [mock(:id => 1), mock(:id => 2), mock(:id => 3)]
      session[:alerts] = alerts
      controller.send(:filter_dismissed_alerts)
      session[:alerts].count.should be 1
      session[:alerts].first.id.should be 2
    end

    it "checks if last check was more then 12 hours" do
      Spree::Config.set :check_for_spree_alerts => true
      Spree::Config.set :last_check_for_spree_alerts => 13.hours.ago.to_s
      controller.send(:should_check_alerts?).should be_true
    end

    it "does not check if last check was recent" do
      Spree::Config.set :check_for_spree_alerts => true
      Spree::Config.set :last_check_for_spree_alerts => 4.hours.ago.to_s
      controller.send(:should_check_alerts?).should be_false
    end

    it "does not check if preference is false" do
      Spree::Config.set :check_for_spree_alerts => false
      controller.send(:should_check_alerts?).should be_false
    end

  end

end


