require 'spec_helper'

describe Spree::AppConfiguration do

  let (:prefs) { Rails.application.config.spree.preferences }

  it "should be available from the environment" do
    prefs.site_name = "TEST SITE NAME"
    prefs.site_name.should eq "TEST SITE NAME"
  end

  it "should be available as Spree::Config for legacy access" do
    Spree::Config.site_name = "Spree::Config TEST SITE NAME"
    Spree::Config.site_name.should eq "Spree::Config TEST SITE NAME"
  end

  it "uses base searcher class by default" do
    prefs.searcher_class = nil
    prefs.searcher_class.should eq Spree::Core::Search::Base
  end

end

