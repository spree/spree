require 'spec_helper'

describe Spree::Asset do
  describe "#viewable" do
    it "touches association" do
      product = create(:custom_product)
      asset = Spree::Asset.create! { |a| a.viewable = product.master }

      product.update_column(:updated_at,  1.day.ago)

      expect do
        asset.touch
      end.to change { product.reload.updated_at }
    end
  end
end
