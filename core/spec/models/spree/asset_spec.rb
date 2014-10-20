require 'spec_helper'

describe Spree::Asset, :type => :model do
  describe "#viewable" do
    it "touches association" do
      product = create(:custom_product)
      asset = Spree::Asset.create! { |a| a.viewable = product.master }

      expect do
        asset.save
      end.to change { product.reload.updated_at }
    end
  end
end
