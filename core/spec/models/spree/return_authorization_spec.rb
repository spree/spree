require 'spec_helper'

describe Spree::ReturnAuthorization do
  let(:stock_location) { Spree::StockLocation.create(:name => "test") }
  let(:order) { create(:shipped_order) }
  let(:rma_reason) { create(:return_authorization_reason) }
  let(:inventory_unit_1) { order.inventory_units.first }

  let(:variant) { order.variants.first }
  let(:return_authorization) do
    Spree::ReturnAuthorization.new(:order => order,
      :stock_location_id => stock_location.id,
      :return_authorization_reason_id => rma_reason.id)
  end

  context "save" do
    let(:order) { Spree::Order.create }

    it "should be invalid when order has no inventory units" do
      return_authorization.save
      return_authorization.errors[:order].should == ["has no shipped units"]
    end
  end

  describe ".before_create" do
    describe "#generate_number" do
      context "number is assigned" do
        let(:return_authorization) { Spree::ReturnAuthorization.new(number: '123') }

        it "should return the assigned number" do
          return_authorization.save
          return_authorization.number.should == '123'
        end
      end

      context "number is not assigned" do
        let(:return_authorization) { Spree::ReturnAuthorization.new(number: nil) }

        before { return_authorization.stub valid?: true }

        it "should assign number with random RA number" do
          return_authorization.save
          return_authorization.number.should =~ /RA\d{9}/
        end
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

    context "to the initial stock location" do
      let!(:return_item) { create(:return_item, inventory_unit: inventory_unit, return_authorization: return_authorization) }

      before do
        return_authorization.stub(:stock_location_id => inventory_unit.shipment.stock_location.id)
        order.stub(:update!)
      end

      it "should mark all inventory units are returned" do
        return_authorization.receive!
        expect(inventory_unit.reload.state).to eq 'returned'
      end

      it "should update the stock item counts in the stock location" do
        expect { return_authorization.receive! }.to change { inventory_unit.find_stock_item.count_on_hand }.by(1)
      end

      context 'with Config.track_inventory_levels == false' do
        before do
          Spree::Config.track_inventory_levels = false
          expect(Spree::StockItem).not_to receive(:find_by)
          expect(Spree::StockMovement).not_to receive(:create!)
        end

        it "should NOT update the stock item counts in the stock location" do
          count_on_hand = inventory_unit.find_stock_item.count_on_hand
          return_authorization.receive!
          expect(inventory_unit.find_stock_item.count_on_hand).to eql count_on_hand
        end
      end
    end

    context "to a different stock location" do
      let(:new_stock_location) { create(:stock_location, :name => "other") }
      let!(:return_item) { create(:return_item, inventory_unit: inventory_unit, return_authorization: return_authorization) }

      before do
        return_authorization.stub(:stock_location_id => new_stock_location.id)
      end

      it "should update the stock item counts in new stock location" do
        expect {
          return_authorization.receive!
        }.to change {
          Spree::StockItem.where(variant_id: inventory_unit.variant_id, stock_location_id: new_stock_location.id).first.count_on_hand
        }.by(1)
      end

      it "should NOT raise an error when no stock item exists in the stock location" do
        inventory_unit.find_stock_item.destroy
        expect { return_authorization.receive! }.not_to raise_error
      end

      it "should not update the stock item counts in the original stock location" do
        count_on_hand = inventory_unit.find_stock_item.count_on_hand
        return_authorization.receive!
        inventory_unit.find_stock_item.count_on_hand.should == count_on_hand
      end
    end
  end

  context "refund!" do
    let(:payment_amount) { 25.50 }
    let(:rma) { create(:return_authorization, order: order, refunds: refunds) }
    let!(:return_item) { create(:return_item, pre_tax_amount: payment_amount, return_authorization: rma) }
    let(:order) { create(:shipped_order) }
    let!(:default_refund_reason) { Spree::RefundReason.find_or_create_by!(name: Spree::RefundReason::RETURN_PROCESSING_REASON, mutable: false) }

    subject { rma.tap(&:refund!) }

    context "the order has completed payments" do

      context "payment amount is enough to refund customer" do
        before { order.payments.completed.first.update_attributes(amount: payment_amount) }

        context "customer has already been refunded for the total amount of the return authorization" do
          let!(:refunds) { [create(:refund, amount: payment_amount)] }

          it "should transition to the refunded state" do
            expect(subject.state).to eq 'refunded'
          end
        end

        context "customer has not received any refund for the return authorization" do
          let!(:refunds) { [] }

          it "should transition to the refunded state" do
            expect(subject.state).to eq 'refunded'
          end

          it "should create a refund" do
            expect{ subject }.to change{ Spree::Refund.count }.by(1)
          end

          it "should create a refund with the amount of the return authorization" do
            refund = subject.reload.refunds.first
            refund.amount.should eq payment_amount
          end
        end

        context "customer has been partially refunded for the total amount of the return authorization" do
          let(:refunded_amount) { payment_amount - 10.0 }
          let!(:refunds) { [create(:refund, amount: refunded_amount)] }

          it "should transition to the refunded state" do
            expect(subject.state).to eq 'refunded'
          end

          it "should create a refund" do
            expect{ subject }.to change{ Spree::Refund.count }.by(1)
          end

          it "should create a refund with the remaining amount required to refund the total amount of the return authorization" do
            refund = subject.reload.refunds.last # first refund is the partial refund
            refund.amount.should eq (payment_amount - refunded_amount)
          end
        end
      end

      context "payment amount is not enough to refund customer" do
        before { order.payments.completed.first.update_attributes(amount: 1.0) }

        context "customer has already been refunded for the total amount of the return authorization" do
          let!(:refunds) { [create(:refund, amount: payment_amount)] }

          it "should transition to the refunded state" do
            expect(subject.state).to eq 'refunded'
          end
        end

        context "customer has not received any refund for the return authorization" do
          let!(:refunds) { [] }

          it "should not transition to the refunded state" do
            expect{ subject }.to raise_error { |e|
              expect(e).to be_a StateMachine::InvalidTransition
              expect(e.message).to include(I18n.t('activerecord.errors.models.spree/return_authorization.attributes.base.amount_due_greater_than_zero'))
            }
          end

          it "should not create a refund" do
            expect do
              expect{ subject }.to raise_error(StateMachine::InvalidTransition)
            end.to_not change{ Spree::Refund.count }
          end
        end

        context "customer has been partially refunded for the total amount of the return authorization" do
          let(:refunded_amount) { payment_amount - 10.0 }
          let!(:refunds) { [create(:refund, amount: refunded_amount)] }

          it "should not transition to the refunded state" do
            expect{ subject }.to raise_error(StateMachine::InvalidTransition)
          end

          it "should not create a refund" do
            expect do
              expect{ subject }.to raise_error(StateMachine::InvalidTransition)
            end.to_not change{ Spree::Refund.count }
          end
        end
      end

      context "too much was already refunded" do
        let!(:refunds) { [create(:refund, amount: payment_amount+1)] }

        it "should not transition to the refunded state" do
          expect{ subject }.to raise_error { |e|
            expect(e).to be_a StateMachine::InvalidTransition
            expect(e.message).to include(I18n.t('activerecord.errors.models.spree/return_authorization.attributes.base.amount_due_less_than_zero'))
          }
        end
      end
    end

    context "the order doesn't have any completed payments" do
      before { order.payments.destroy_all }

      context "customer has already been refunded for the total amount of the return authorization" do
        let!(:refunds) { [create(:refund, amount: payment_amount)] }

        it "should transition to the refunded state" do
          expect(subject.state).to eq 'refunded'
        end
      end

      context "customer has not received any refund for the return authorization" do
        let!(:refunds) { [] }

        it "should not transition to the refunded state" do
          expect{ subject }.to raise_error(StateMachine::InvalidTransition)
        end
      end

      context "customer has been partially refunded for the total amount of the return authorization" do
        let!(:refunds) { [create(:refund, amount: payment_amount - 10.0)] }

        it "should not transition to the refunded state" do
          expect{ subject }.to raise_error(StateMachine::InvalidTransition)
        end
      end
    end

    context "return authorization amount is zero" do
      let(:payment_amount) { 0.0 }
      let(:refunds) { [] }

      it "should transition to the refunded state" do
        expect(subject.state).to eq 'refunded'
      end
    end
  end

  context "currency" do
    before { order.stub(:currency) { "ABC" } }
    it "returns the order currency" do
      return_authorization.currency.should == "ABC"
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

  describe "#pre_tax_total" do
    let(:pre_tax_amount_1) { 15.0 }
    let!(:return_item_1) { create(:return_item, return_authorization: return_authorization, pre_tax_amount: pre_tax_amount_1) }

    let(:pre_tax_amount_2) { 50.0 }
    let!(:return_item_2) { create(:return_item, return_authorization: return_authorization, pre_tax_amount: pre_tax_amount_2) }

    let(:pre_tax_amount_3) { 5.0 }
    let!(:return_item_3) { create(:return_item, return_authorization: return_authorization, pre_tax_amount: pre_tax_amount_3) }

    subject { return_authorization.pre_tax_total }

    it "sums it's associated return_item's pre-tax amounts" do
      subject.should eq (pre_tax_amount_1 + pre_tax_amount_2 + pre_tax_amount_3)
    end
  end

  describe "#display_pre_tax_total" do
    it "returns a Spree::Money" do
      return_authorization.stub(pre_tax_total: 21.22)
      return_authorization.display_pre_tax_total.should == Spree::Money.new(21.22)
    end
  end

  describe "#additional_tax_total" do
    let(:additional_tax_total_1) { 15.0 }
    let!(:return_item_1) { create(:return_item, return_authorization: return_authorization, additional_tax_total: additional_tax_total_1) }

    let(:additional_tax_total_2) { 50.0 }
    let!(:return_item_2) { create(:return_item, return_authorization: return_authorization, additional_tax_total: additional_tax_total_2) }

    let(:additional_tax_total_3) { 5.0 }
    let!(:return_item_3) { create(:return_item, return_authorization: return_authorization, additional_tax_total: additional_tax_total_3) }

    subject { return_authorization.additional_tax_total }

    it "sums it's associated return_item's additional tax totals" do
      subject.should eq (additional_tax_total_1 + additional_tax_total_2 + additional_tax_total_3)
    end
  end

  describe "total" do
    let(:pre_tax_amount_1) { 15.0 }
    let(:additional_tax_total_1) { 1.0 }
    let!(:return_item_1) do
      create(:return_item,
             return_authorization: return_authorization,
             pre_tax_amount: pre_tax_amount_1,
             additional_tax_total: additional_tax_total_1)
    end

    let(:pre_tax_amount_2) { 50.0 }
    let(:additional_tax_total_2) { 3.2 }
    let!(:return_item_2) do
      create(:return_item,
             return_authorization: return_authorization,
             pre_tax_amount: pre_tax_amount_2,
             additional_tax_total: additional_tax_total_2)
    end

    let(:pre_tax_amount_3) { 23.90 }
    let(:additional_tax_total_3) { 2.07 }
    let!(:return_item_3) do
      create(:return_item,
             return_authorization: return_authorization,
             pre_tax_amount: pre_tax_amount_3,
             additional_tax_total: additional_tax_total_3)
    end

    subject { return_authorization.total }

    it "sums the return item's pre-tax total and additional tax total" do
      total_1 = pre_tax_amount_1 + additional_tax_total_1
      total_2 = pre_tax_amount_2 + additional_tax_total_2
      total_3 = pre_tax_amount_3 + additional_tax_total_3
      subject.should eq total_1 + total_2 + total_3
    end
  end

  describe "#amount_due" do
    let(:pre_tax_amount) { 15.0 }
    let(:additional_tax_total) { 1.0 }
    let!(:return_item_1) do
      create(:return_item,
             return_authorization: return_authorization,
             pre_tax_amount: pre_tax_amount,
             additional_tax_total: additional_tax_total)
    end

    subject { return_authorization.amount_due }

    context "no refunds" do
      it "returns the rma total" do
        subject.should eq return_authorization.total
      end
    end

    context "refunds" do
      let(:refund_amount) { 2.5 }

      before do
        return_authorization.refunds << create(:refund, amount: refund_amount)
      end

      it "subtracts the refunded amount from the rma total" do
        subject.should eq return_authorization.total - refund_amount
      end
    end
  end

  describe "#refundable_amount" do
    let(:weighted_line_item_pre_tax_amount) { 5.0 }
    let(:line_item_count)                   { return_authorization.order.line_items.count }

    subject { return_authorization.refundable_amount }

    before do
      return_authorization.order.line_items.update_all(pre_tax_amount: weighted_line_item_pre_tax_amount)
      return_authorization.order.update_attribute(:promo_total, promo_total)
    end

    context "no promotions" do
      let(:promo_total) { 0.0 }

      it "returns the pre-tax line item total" do
        subject.should eq (weighted_line_item_pre_tax_amount * line_item_count)
      end
    end

    context "promotions" do
      let(:promo_total) { -10.0 }

      it "returns the pre-tax line item total minus the order level promotion value" do
        subject.should eq (weighted_line_item_pre_tax_amount * line_item_count) + promo_total
      end
    end
  end
end
