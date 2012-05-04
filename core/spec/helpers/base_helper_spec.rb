require 'spec_helper'

describe Spree::BaseHelper do
  include Spree::BaseHelper

  # Regression test for #889
  context "seo_url" do
    let(:taxon) { stub(:permalink => "bam") }
    it "provides the correct URL" do
      seo_url(taxon).should == "/t/bam"
    end
  end

  # Regression test for #1436
  context "defining custom image helpers" do
    let(:product) { mock_model(Spree::Product, :images => []) }
    before do
      Spree::Image.class_eval do
        attachment_definitions[:attachment][:styles].merge!({:very_strange => '1x1'})
      end
    end

    it "should not raise errors when style exists" do
      lambda { very_strange_image(product) }.should_not raise_error
    end

    it "should raise NoMethodError when style is not exists" do
      lambda { another_strange_image(product) }.should raise_error(NoMethodError)
    end

  end
end
