require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe FlexiRate do
      let(:variant1) { build(:variant, :price => 10) }
      let(:variant2) { build(:variant, :price => 20) }
      let(:package) { double(Stock::Package,
                           order: mock_model(Order),
                           contents: [Stock::Package::ContentItem.new(variant1, 4),
                                      Stock::Package::ContentItem.new(variant2, 6)]) }

      let(:subject) { FlexiRate.new }

      context "compute" do
        it "should compute amount correctly when all fees are 0" do
          subject.compute(package).round(2).should == 0.0
        end

        it "should compute amount correctly when first_item has a value" do
          subject.preferred_first_item = 1.0
          subject.compute(package).round(2).should == 1.0
        end

        it "should compute amount correctly when additional_items has a value" do
          subject.preferred_additional_item = 1.0
          subject.compute(package).round(2).should == 9.0
        end

        it "should compute amount correctly when additional_items and first_item have values" do
          subject.preferred_first_item = 5.0
          subject.preferred_additional_item = 1.0
          subject.compute(package).round(2).should == 14.0
        end

        it "should compute amount correctly when additional_items and first_item have values AND max items has value" do
          subject.preferred_first_item = 5.0
          subject.preferred_additional_item = 1.0
          subject.preferred_max_items = 3
          subject.compute(package).round(2).should == 26.0
        end

        it "should allow creation of new object with all the attributes" do
          FlexiRate.new(:preferred_first_item => 1,
                        :preferred_additional_item => 1,
                        :preferred_max_items => 1)
        end
      end
    end
  end
end

