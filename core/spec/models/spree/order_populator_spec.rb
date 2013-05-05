require 'spec_helper'

describe Spree::OrderPopulator do
  let(:order) { double('Order') }
  let(:item) { double('Item') }
  subject { Spree::OrderPopulator.new(order, "USD") }

  context "with stubbed out find_variant" do
    let(:variant) { double('Variant', :name => "T-Shirt", :options_text => "Size: M") }
    before do
     Spree::Variant.stub(:find).and_return(variant) 
     order.should_receive(:contents).at_least(:once).and_return(Spree::OrderContents.new(self))
    end

    context "takes a list of products" do
      context "quantity greater than 0" do
        before do
          subject.stub(:check_stock_levels => true)
          order.contents.should_receive(:add).with(variant, 1, subject.currency).and_return(item)
        end

        it "adds record to items list" do
          subject.populate(:products => { 1 => 2 }, :quantity => 1)
          subject.items.should == [item]
        end
      end

      context "quantity is set to 0" do
        it "keeps items list empty" do
          order.contents.should_not_receive(:add)
          subject.items.should be_empty
          subject.populate(:products => { 1 => 2 }, :quantity => 0)
        end
      end

      it "should add an error if the variant is out of stock" do
        Spree::Stock::Quantifier.any_instance.stub(can_supply?: false)
        order.contents.should_not_receive(:add)
        subject.populate(:products => { 1 => 2 }, :quantity => 1)
        subject.should_not be_valid
        subject.errors.full_messages.join("").should == %Q{"T-Shirt (Size: M)" is out of stock.}
      end

      # Regression test for #2430
      context "respects allow_backorders setting" do
        before do
          Spree::Config[:allow_backorders] = true
          # Variant is available due to allow_backorders
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

    context "takes a list of variants with quantites" do
      before do
        subject.stub(:check_stock_levels => true)
        order.contents.should_receive(:add).with(variant, 5, subject.currency).and_return(item)
      end

      it "adds record to items list" do
        subject.populate(:variants => { 2 => 5 })
        subject.items.should == [item]
      end
    end
  end
end
