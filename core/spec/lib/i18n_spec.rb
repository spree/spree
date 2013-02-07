require 'rspec/expectations'
require 'spree/i18n'

describe "i18n" do
  it "translates within the spree scope" do
    Spree.t(:foo).include?("en.spree.foo").should be_true
  end

  it "prepends a string scope" do
    Spree.t(:foo, :scope => "bar").include?("en.spree.bar.foo").should be_true
  end

  it "prepends to an array scope" do
    Spree.t(:foo, :scope => ["bar"]).include?("en.spree.bar.foo").should be_true
  end
end
