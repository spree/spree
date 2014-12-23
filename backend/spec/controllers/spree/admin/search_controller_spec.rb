require 'spec_helper'

describe Spree::Admin::SearchController, :type => :controller do
  stub_authorization!
  # Regression test for ernie/ransack#176

  describe "users" do
    let(:user) { create(:user, :email => "spree_commerce@example.com") }

    before do
      user.ship_address = create(:address)
      user.bill_address = create(:address)
      user.save
    end

    it "can find a user by their email "do
      spree_xhr_get :users, :q => user.email
      expect(assigns[:users]).to include(user)
    end

    it "can find a user by their ship address's first name" do
      spree_xhr_get :users, :q => user.ship_address.firstname
      expect(assigns[:users]).to include(user)
    end

    it "can find a user by their ship address's last name" do
      spree_xhr_get :users, :q => user.ship_address.lastname
      expect(assigns[:users]).to include(user)
    end

    it "can find a user by their bill address's first name" do
      spree_xhr_get :users, :q => user.bill_address.firstname
      expect(assigns[:users]).to include(user)
    end

    it "can find a user by their bill address's last name" do
      spree_xhr_get :users, :q => user.bill_address.lastname
      expect(assigns[:users]).to include(user)
    end
  end

  describe "products" do
    let(:product) { create(:product, :name => "Example Product") }

    it "can find a product by its name "do
      spree_xhr_get :products, :q => product.name
      expect(assigns[:products]).to include(product)
    end

    it "can find a product by its slug "do
      spree_xhr_get :products, :q => product.slug
      expect(assigns[:products]).to include(product)
    end
  end

end
