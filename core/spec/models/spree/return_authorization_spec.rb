require 'spec_helper'

describe Spree::ReturnAuthorization do
  let(:stock_location) {Spree::StockLocation.create(:name => "test") }
  let(:order) { FactoryGirl.create(:shipped_order) }
  let(:variant) { order.shipments.first.inventory_units.first.variant }
  let(:return_authorization) { Spree::ReturnAuthorization.new(:order => order, :stock_location_id => stock_location.id) }

  context "save" do
    it "should be invalid when order has no inventory units" do
      order.shipments.destroy_all
      return_authorization.save
      return_authorization.errors[:order].should == ["has no shipped units"]
    end
  end

  describe ".before_create" do
    describe "#generate_number" do
      context "number is assigned" do
        let(:return_authorization) { FactoryGirl.build(:return_authorization, number: '123') }

        it "should return the assigned number" do
          return_authorization.save
          return_authorization.number.should == '123'
        end
      end

      context "number is not assigned" do
        let(:return_authorization) { FactoryGirl.build(:return_authorization, number: nil) }

        it "should assign number with random RMA number" do
          return_authorization.save
          return_authorization.number.should =~ /RMA\d{9}/
        end
      end
    end
  end

  context "add_variant" do
    context "on empty rma" do
      it "should associate inventory unit" do
        return_authorization.add_variant(variant.id, 1)
        return_authorization.inventory_units.size.should == 1
      end

      it "should associate inventory units as shipped" do
        return_authorization.add_variant(variant.id, 1)
        expect(return_authorization.inventory_units.where(state: 'shipped').size).to eq 1
      end

      it "should update order state" do
        order.should_receive(:authorize_return!)
        return_authorization.add_variant(variant.id, 1)
      end
    end

    context "on rma that already has inventory_units" do
      before do
        return_authorization.add_variant(variant.id, 1)
      end

      it "should not associate more inventory units than there are on the order" do
        return_authorization.add_variant(variant.id, 1)
        expect(return_authorization.inventory_units.size).to eq 1
      end

      it "should not update order state" do
        expect{return_authorization.add_variant(variant.id, 1)}.to_not change{order.state}
      end
    end
  end

  context "can_receive?" do
    it "should allow_receive when inventory units assigned" do
      return_authorization.stub(:inventory_units => [1,2,3])
      return_authorization.can_receive?.should be_true
    end

    it "should not allow_receive with no inventory units" do
      return_authorization.stub(:inventory_units => [])
      return_authorization.can_receive?.should be_false
    end
  end

  context "receive!" do
    let(:inventory_unit) { order.shipments.first.inventory_units.first }

    before  do
      return_authorization.stub(:inventory_units => [inventory_unit], :amount => -20)
      Spree::Adjustment.stub(:create)
      order.stub(:update!)
    end

    it "should mark all inventory units are returned" do
      inventory_unit.should_receive(:return!)
      return_authorization.receive!
    end

    it "should add credit for specified amount" do
      return_authorization.amount = 20
      mock_adjustment = double
      mock_adjustment.should_receive(:source=).with(return_authorization)
      mock_adjustment.should_receive(:adjustable=).with(order)
      mock_adjustment.should_receive(:save)
      Spree::Adjustment.should_receive(:new).with(:amount => -20, :label => Spree.t(:rma_credit)).and_return(mock_adjustment)
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
      return_authorization.run_callbacks(:save)
    end
  end

  context "currency" do
    before { order.stub(:currency) { "ABC" } }
    it "returns the order currency" do
      return_authorization.currency.should == "ABC"
    end
  end

  context "display_amount" do
    it "returns a Spree::Money" do
      return_authorization.amount = 21.22
      return_authorization.display_amount.should == Spree::Money.new(21.22)
    end
  end

  context "returnable_inventory" do
    pending "should return inventory from shipped shipments" do
      return_authorization.returnable_inventory.should == [inventory_unit]
    end

    pending "should not return inventory from unshipped shipments" do
      return_authorization.returnable_inventory.should == []
    end
  end
end
