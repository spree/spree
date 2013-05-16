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
        subject.stub(:check_stock_levels => true)
        order.contents.should_receive(:add).with(variant, 1, subject.currency)
        subject.populate(:products => { 1 => 2 }, :quantity => 1)
      end

      it "does not add any products if a quantity is set to 0" do
        order.contents.should_not_receive(:add)
        subject.populate(:products => { 1 => 2 }, :quantity => 0)
      end

      it "should add an error if the variant is out of stock" do
        Spree::Stock::Quantifier.any_instance.stub(can_supply?: false)
        order.contents.should_not_receive(:add)
        subject.populate(:products => { 1 => 2 }, :quantity => 1)
        subject.should_not be_valid
        subject.errors.full_messages.join("").should == %Q{"T-Shirt (Size: M)" is out of stock.}
      end

      # Regression test for #2430
      context "respects backorderable setting" do
        before do
          Spree::Stock::Quantifier.any_instance.stub(can_supply?: true)
        end

        it "allows an order to be populated, even though item stock is depleted" do
          order.contents.should_receive(:add).with(variant, 3, subject.currency)
          subject.populate(:products => { 1 => 2 }, :quantity => 3)
          subject.should be_valid
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
        subject.stub(:check_stock_levels => true)
        order.contents.should_receive(:add).with(variant, 5, subject.currency)
        subject.populate(:variants => { 2 => 5 })
      end
    end
  end
end
