require 'spec_helper'

describe Spree::Admin::SearchController do
  stub_authorization!
  # Regression test for ernie/ransack#176
  let(:user) { create(:user, :email => "spree_commerce@example.com") }

  before do
    user.ship_address = create(:address)
    user.bill_address = create(:address)
    user.save
  end

  it "can find a user by their email "do
    spree_xhr_get :users, :q => user.email
    assigns[:users].should include(user)
  end

  it "can find a user by their ship address's first name" do
    spree_xhr_get :users, :q => user.ship_address.firstname
    assigns[:users].should include(user)
  end

  it "can find a user by their ship address's last name" do
    spree_xhr_get :users, :q => user.ship_address.lastname
    assigns[:users].should include(user)
  end

  it "can find a user by their bill address's first name" do
    spree_xhr_get :users, :q => user.bill_address.firstname
    assigns[:users].should include(user)
  end

  it "can find a user by their bill address's last name" do
    spree_xhr_get :users, :q => user.bill_address.lastname
    assigns[:users].should include(user)
  end

end
