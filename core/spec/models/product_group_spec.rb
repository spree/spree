require 'spec_helper'

describe Spree::ProductGroup do

  context "validations" do
    it { should validate_presence_of(:name) }
    it { should have_valid_factory(:product_group) }
  end

  describe '#from_route' do
    context "wth valid scopes" do
      before do
        subject.from_route(["master_price_lte", "100", "in_name_or_keywords", "Ikea", "ascend_by_master_price"])
      end

      it "sets one ordering scope" do
        subject.product_scopes.select(&:is_ordering?).length.should == 1
      end

      it "sets two non-ordering scopes" do
        subject.product_scopes.reject(&:is_ordering?).length.should == 2
      end
    end

    context 'with an invalid product scope' do
      before do
        subject.from_route(["master_pri_lte", "100", "in_name_or_kerds", "Ikea"])
      end

      it 'sets no product scopes' do
        subject.product_scopes.should be_empty
      end
    end

  end

  # Regression test for #774
  context "Regression test for #774" do

    let!(:property) { Factory(:property, :name => "test") }
    let!(:product) do
      product = Factory(:product)
      product.properties << property
    end

    let!(:product_scope) { Factory(:product_scope, :name => "with_property", :arguments => ["test"]) }
    let!(:product_group) { Factory(:product_group, :product_scopes => [product_scope]) }

    it "updates a product group when a property is deleted" do
      pending
      product_group.products.should include(product)
      property.destroy
      product_group.products(true).should_not include(products)
    end

  end
end
