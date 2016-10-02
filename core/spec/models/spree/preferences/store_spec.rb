require 'spec_helper'

describe Spree::Preferences::Store do
  before :each do
    @store = Spree::Preferences::StoreInstance.new
  end

  it "sets and gets a key" do
    @store.set :test, 1, :integer
    @store.exist?(:test).should be true
    @store.get(:test).should eq 1
  end

  it "can set and get false values when cache return nil" do
    @store.set :test, false, :boolean
    @store.get(:test).should be false
  end

  it "will return db value when cache is emtpy and cache the db value" do
    preference = Spree::Preference.where(:key => 'test').first_or_initialize
    preference.value = '123'
    preference.value_type = 'string'
    preference.save

    Rails.cache.clear
    @store.get(:test).should eq '123'
    Rails.cache.read(:test).should eq '123'
  end

  it "should return and cache fallback value when supplied" do
    Rails.cache.clear
    @store.get(:test, false).should be false
    Rails.cache.read(:test).should be false
  end

  it "should return but not cache fallback value when persistence is disabled" do
    Rails.cache.clear
    @store.stub(:should_persist? => false)
    @store.get(:test, true).should be true
    Rails.cache.exist?(:test).should be false
  end

  it "should return nil when key can't be found and fallback value is not supplied" do
    @store.get(:random_key).should be_nil
  end

end
