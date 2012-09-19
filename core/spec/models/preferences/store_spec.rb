require 'spec_helper'

describe Spree::Preferences::Store do
  before :each do
    @store = Spree::Preferences::StoreInstance.new
  end

  it "sets and gets a key" do
    @store.set :test, 1, :integer
    @store.exist?(:test).should be_true
    @store.get(:test).should eq 1
  end

  it "can set and get false values when cache return nil" do
    @store.set :test, false, :boolean
    @store.get(:test).should be_false
  end

  it "returns the correct preference value when the cache is empty" do
    @store.set :test, "1", :string
    Rails.cache.clear
    @store.get(:test).should == "1"
  end
end
