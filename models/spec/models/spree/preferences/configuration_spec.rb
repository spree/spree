require 'spec_helper'

describe Spree::Preferences::Configuration do

  before :all do
    class AppConfig < Spree::Preferences::Configuration
      preference :color, :string, :default => :blue
    end
    @config = AppConfig.new
  end

  it "has named methods to access preferences" do
    @config.color = 'orange'
    @config.color.should eq 'orange'
  end

  it "uses [ ] to access preferences" do
    @config[:color] = 'red'
    @config[:color].should eq 'red'
  end

  it "uses set/get to access preferences" do
    @config.set :color, 'green'
    @config.get(:color).should eq 'green'
  end

end



