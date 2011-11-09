require 'spec_helper'

describe "product scopes" do
  context "by_updated_at" do
    let!(:product_1) { Factory(:product, :updated_at => 1.day.ago) }
    let!(:product_2) { Factory(:product, :updated_at => 1.day.from_now) }

    it "ascending" do
      Spree::Product.ascend_by_updated_at.should == [product_1, product_2]
    end

    it "descending" do
      Spree::Product.descend_by_updated_at.should == [product_2, product_1]
    end
  end
end
