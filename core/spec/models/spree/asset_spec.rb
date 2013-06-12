require 'spec_helper'

describe Spree::Asset do

  describe "#viewable" do

    it "touches association" do
      product = create(:custom_product)
      asset = Spree::Asset.create! { |a| a.viewable = product.master }

      old_updated_at = 100.years.ago
      product.update_column(:updated_at, old_updated_at)

      expect do
        asset.touch
      end.to change { product.reload.updated_at }.from(old_updated_at)
    end

  end

end
