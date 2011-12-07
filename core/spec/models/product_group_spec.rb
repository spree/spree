# coding: UTF-8

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
      product
    end

    let!(:product_group) do
     product_group = Factory(:product_group, :name => "Not sports")
     product_group.product_scopes.create!(:name => "with_property", :arguments => ["test"])
     product_group
    end

    it "updates a product group when a property is deleted" do
      product_group.products.should include(product)
      property.destroy
      product_group.products(true).should_not include(product)
    end

  end

  # Regression test for issue raised here: https://github.com/spree/spree/pull/847#issuecomment-3048822
  context "generates correct permalink" do
    it "for Chinese" do
      product_group = Spree::ProductGroup.new(:name => "你好")
      product_group.set_permalink.should == "ni-hao"
    end
  end
end
