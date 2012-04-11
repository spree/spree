require 'spec_helper'

# In this file, we want to test that the controller helpers function correctly
# So we need to use one of the controllers inside Spree.
# ProductsController is good.
describe Spree::ProductsController do

  before do
    I18n.stub(:available_locales => [:en, :de])
    Spree::Config[:default_locale] = nil
    Rails.application.config.i18n.default_locale = :de
  end

  after do
    Spree::Config[:default_locale] = :en
    Rails.application.config.i18n.default_locale = :en
    I18n.locale = :en
  end

  # Regression test for #1184
  it "sets the default locale based off config.i18n.default_locale" do
    I18n.locale.should == :en
    spree_get :index
    I18n.locale.should == :de
  end
end
