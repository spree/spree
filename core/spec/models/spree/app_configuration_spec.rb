require 'spec_helper'

describe Spree::AppConfiguration do

  let (:prefs) { Rails.application.config.spree.preferences }

  it "should be available from the environment" do
    prefs.layout = "my/layout"
    prefs.layout.should eq "my/layout"
  end

  it "should be available as Spree::Config for legacy access" do
    Spree::Config.layout = "my/layout"
    Spree::Config.layout.should eq "my/layout"
  end

  it "uses base searcher class by default" do
    prefs.searcher_class = nil
    prefs.searcher_class.should eq Spree::Core::Search::Base
  end

end

