require 'spec_helper'

describe Spree::Admin::SearchController, type: :controller do
  stub_authorization!
  # Regression test for ernie/ransack#176

  describe "products" do
    let(:product) { create(:product, name: "Example Product") }

    it "can find a product by its name "do
      spree_xhr_get :products, q: product.name
      expect(assigns[:products]).to include(product)
    end

    it "can find a product by its slug "do
      spree_xhr_get :products, q: product.slug
      expect(assigns[:products]).to include(product)
    end
  end

  describe "tags" do
    let(:tag) { create(:tag, name: "Awesome Product") }

    it "can find a tag by its name" do
      spree_xhr_get :tags, q: tag.name
      expect(assigns[:tags]).to include(tag)
    end
  end
end
