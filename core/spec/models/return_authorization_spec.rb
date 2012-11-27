require 'spec_helper'

describe Spree::ReturnAuthorization do
  let(:inventory_unit) { Spree::InventoryUnit.create({:variant => mock_model(Spree::Variant)}, :without_protection => true) }
  let(:order) { mock_model(Spree::Order, :inventory_units => [inventory_unit], :awaiting_return? => false) }
  let(:return_authorization) { Spree::ReturnAuthorization.new({:order => order}, :without_protection => true) }

  before { inventory_unit.stub(:shipped?).and_return(true) }

  context "save" do
    it "should be invalid when order has no inventory units" do
      inventory_unit.stub(:shipped?).and_return(false)
      return_authorization.save
      return_authorization.errors[:order].should == ["has no shipped units"]
    end

    it "should generate RMA number" do
      return_authorization.should_receive(:generate_number)
      return_authorization.save
    end
  end

  context "add_variant" do
    context "on empty rma" do
      it "should associate inventory unit" do
        order.stub(:authorize_return!)
        return_authorization.add_variant(inventory_unit.variant.id, 1)
        return_authorization.inventory_units.size.should == 1
        inventory_unit.return_authorization.should == return_authorization
      end

      it "should update order state" do
        order.should_receive(:authorize_return!)
        return_authorization.add_variant(inventory_unit.variant.id, 1)
      end
    end

    context "on rma that already has inventory_units" do
      let(:inventory_unit_2)  { Spree::InventoryUnit.create({:variant => inventory_unit.variant}, :without_protection => true) }
      before { order.stub(:inventory_units => [inventory_unit, inventory_unit_2], :awaiting_return? => true) }

      it "should associate inventory unit" do
        order.stub(:authorize_return!)
        return_authorization.add_variant(inventory_unit.variant.id, 2)
        return_authorization.inventory_units.size.should == 2
        inventory_unit_2.return_authorization.should == return_authorization
      end

      it "should not update order state" do
        order.should_not_receive(:authorize_return!)
        return_authorization.add_variant(inventory_unit.variant.id, 1)
      end

    end

  end

  context "can_receive?" do
    it "should allow_receive when inventory units assigned" do
      return_authorization.stub(:inventory_units => [inventory_unit])
      return_authorization.can_receive?.should be_true
    end

    it "should not allow_receive with no inventory units" do
      return_authorization.can_receive?.should be_false
    end
  end

  context "receive!" do
    before  do
      inventory_unit.stub(:state => "shipped", :return! => true)
      return_authorization.stub(:inventory_units => [inventory_unit], :amount => -20)
      Spree::Adjustment.stub(:create)
      order.stub(:update!)
    end

    it "should mark all inventory units are returned" do
      inventory_unit.should_receive(:return!)
      return_authorization.receive!
    end

    it "should add credit for specified amount" do
      mock_adjustment = mock
      mock_adjustment.should_receive(:source=).with(return_authorization)
      mock_adjustment.should_receive(:adjustable=).with(order)
      mock_adjustment.should_receive(:save)
      Spree::Adjustment.should_receive(:new).with(:amount => -20, :label => I18n.t(:rma_credit)).and_return(mock_adjustment)
      return_authorization.receive!
    end

    it "should update order state" do
      order.should_receive :update!
      return_authorization.receive!
    end
  end

  context "force_positive_amount" do
    it "should ensure the amount is always positive" do
      return_authorization.amount = -10
      return_authorization.send :force_positive_amount
      return_authorization.amount.should == 10
    end
  end

  context "after_save" do
    it "should run correct callbacks" do
      return_authorization.should_receive(:force_positive_amount)
      return_authorization.run_callbacks(:save, :after)
    end
  end

  context "currency" do
    before { order.stub(:currency) { "ABC" } }
    it "returns the order currency" do
      return_authorization.currency.should == "ABC"
    end
  end

  context "display_amount" do
    it "retuns a Spree::Money" do
      return_authorization.amount = 21.22
      return_authorization.display_amount.should == Spree::Money.new(21.22)
    end
  end
end
