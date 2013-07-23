require 'spec_helper'

describe Spree::OrderPopulator do
  let(:order) { double('Order') }
  subject { Spree::OrderPopulator.new(order, "USD") }

  context "with stubbed out find_variant" do
    let(:variant) { double('Variant', :name => "T-Shirt", :options_text => "Size: M") }

    before do
     Spree::Variant.stub(:find).and_return(variant) 
     order.should_receive(:contents).at_least(:once).and_return(Spree::OrderContents.new(self))
    end

    context "with products parameters" do
      it "can take a list of products and add them to the order" do
        order.contents.should_receive(:add).with(variant, 1, subject.currency).and_return double.as_null_object
        subject.populate(:products => { 1 => 2 }, :quantity => 1)
      end

      it "does not add any products if a quantity is set to 0" do
        order.contents.should_not_receive(:add)
        subject.populate(:products => { 1 => 2 }, :quantity => 0)
      end

      context "variant out of stock" do
        before do
          line_item = double("LineItem", valid?: false)
          line_item.stub_chain(:errors, messages: { quantity: ["error message"] })
          order.contents.stub(add: line_item)
        end

        it "adds an error when trying to populate" do
          subject.populate(:products => { 1 => 2 }, :quantity => 1)
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages.join).to eql "error message"
        end
      end

      # Regression test for #2695
      it "restricts quantities to reasonable sizes (less than 2.1 billion, seriously)" do
        order.contents.should_not_receive(:add)
        subject.populate(:products => { 1 => 2 }, :quantity => 2_147_483_648)
        subject.should_not be_valid
        output = "Please enter a reasonable quantity."
        subject.errors.full_messages.join("").should == output
      end
    end

    context "with variant parameters" do
      it "can take a list of variants with quantites and add them to the order" do
        order.contents.should_receive(:add).with(variant, 5, subject.currency).and_return double.as_null_object
        subject.populate(:variants => { 2 => 5 })
      end
    end
  end
end
