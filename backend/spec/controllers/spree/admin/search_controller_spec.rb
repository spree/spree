require 'spec_helper'

describe Spree::Admin::SearchController, type: :controller do
  stub_authorization!

  describe "tags" do
    let(:tag) { create(:tag, name: "Awesome Product") }

    it "can find a tag by its name" do
      spree_xhr_get :tags, q: tag.name
      expect(assigns[:tags]).to include(tag)
    end
  end
end
