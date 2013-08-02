require 'spec_helper'

module Spree
  describe OrderUpdater do
    let(:order) { stub_model(Spree::Order, :backordered? => false) }
    let(:updater) { Spree::OrderUpdater.new(order) }

    it "updates totals" do
      payments = [double(:amount => 5), double(:amount => 5)]
      order.stub_chain(:payments, :completed).and_return(payments)

      line_items = [double(:amount => 10), double(:amount => 20)]
      order.stub :line_items => line_items

      adjustments = [double(:amount => 10), double(:amount => -20)]
      order.stub_chain(:adjustments, :eligible).and_return(adjustments)

      updater.update_totals
      order.payment_total.should == 10
      order.item_total.should == 30
      order.adjustment_total.should == -10
      order.total.should == 20
    end

    context "updating shipment state" do
      before do
        order.stub_chain(:shipments, :shipped, :count).and_return(0)
        order.stub_chain(:shipments, :ready, :count).and_return(0)
        order.stub_chain(:shipments, :pending, :count).and_return(0)
      end

      it "is backordered" do
        order.stub :backordered? => true
        updater.update_shipment_state

        order.shipment_state.should == 'backorder'
      end

      it "is nil" do
        order.stub_chain(:shipments, :states).and_return([])
        order.stub_chain(:shipments, :count).and_return(0)

        updater.update_shipment_state
        order.shipment_state.should be_nil
      end


      ["shipped", "ready", "pending"].each do |state|
        it "is #{state}" do
          order.stub_chain(:shipments, :states).and_return([state])
          updater.update_shipment_state
          order.shipment_state.should == state.to_s
        end
      end

      it "is partial" do
        order.stub_chain(:shipments, :states).and_return(["pending", "ready"])
        updater.update_shipment_state
        order.shipment_state.should == 'partial'
      end
    end

    context "updating payment state" do
      it "is failed if last payment failed" do
        order.stub_chain(:payments, :last, :state).and_return('failed')

        updater.update_payment_state
        order.payment_state.should == 'failed'
      end

      it "is balance due with no line items" do
        order.stub_chain(:line_items, :empty?).and_return(true)

        updater.update_payment_state
        order.payment_state.should == 'balance_due'
      end

      it "is credit owed if payment is above total" do
        order.stub_chain(:line_items, :empty?).and_return(false)
        order.stub :payment_total => 31
        order.stub :total => 30

        updater.update_payment_state
        order.payment_state.should == 'credit_owed'
      end

      it "is paid if order is paid in full" do
        order.stub_chain(:line_items, :empty?).and_return(false)
        order.stub :payment_total => 30
        order.stub :total => 30

        updater.update_payment_state
        order.payment_state.should == 'paid'
      end
    end

    it "state change" do
      order.shipment_state = 'shipped'
      state_changes = double
      order.stub :state_changes => state_changes
      state_changes.should_receive(:create).with({
        :previous_state => nil,
        :next_state => 'shipped',
        :name => 'shipment',
        :user_id => nil
      }, :without_protection => true)

      order.state_changed('shipment')
    end

    context "completed order" do
      before { order.stub completed?: true }

      it "updates payment state" do
        expect(updater).to receive(:update_payment_state)
        updater.update
      end

      it "updates shipment state" do
        expect(updater).to receive(:update_shipment_state)
        updater.update
      end

      it "updates each shipment" do
        shipment = stub_model(Spree::Shipment)
        shipments = [shipment]
        order.stub :shipments => shipments
        shipments.stub :states => []
        shipments.stub :ready => []
        shipments.stub :pending => []
        shipments.stub :shipped => []

        shipment.should_receive(:update!).with(order)
        updater.update
      end
    end

    context "incompleted order" do
      before { order.stub completed?: false }

      it "doesnt update payment state" do
        expect(updater).not_to receive(:update_payment_state)
        updater.update
      end

      it "doesnt update shipment state" do
        expect(updater).not_to receive(:update_shipment_state)
        updater.update
      end

      it "doesnt update each shipment" do
        shipment = stub_model(Spree::Shipment)
        shipments = [shipment]
        order.stub :shipments => shipments
        shipments.stub :states => []
        shipments.stub :ready => []
        shipments.stub :pending => []
        shipments.stub :shipped => []

        expect(shipment).not_to receive(:update!).with(order)
        updater.update
      end
    end

    it "updates totals twice" do
      updater.should_receive(:update_totals).twice
      updater.update
    end

    context "update adjustments" do
      context "shipments" do
        it "updates" do
          expect(updater).to receive(:update_shipping_adjustments)
          updater.update
        end
      end

      context "promotions" do
        let(:originator) do
          originator = Spree::Promotion::Actions::CreateAdjustment.create
          calculator = Spree::Calculator::PerItem.create({:calculable => originator}, :without_protection => true)
          originator.calculator = calculator
          originator.save
          originator
        end

        def create_adjustment(label, amount)
          create(:adjustment, :adjustable => order,
                              :originator => originator,
                              :amount     => amount,
                              :state      => "closed",
                              :label      => label,
                              :mandatory  => false)
        end

        it "should make all but the most valuable promotion adjustment ineligible, leaving non promotion adjustments alone" do
          create_adjustment("Promotion A", -100)
          create_adjustment("Promotion B", -200)
          create_adjustment("Promotion C", -300)
          create(:adjustment, :adjustable => order,
                              :originator => nil,
                              :amount => -500,
                              :state => "closed",
                              :label => "Some other credit")
          order.adjustments.each {|a| a.update_attribute_without_callbacks(:eligible, true)}

          updater.update_promotion_adjustments

          order.adjustments.eligible.promotion.count.should == 1
          order.adjustments.eligible.promotion.first.label.should == 'Promotion C'
        end

        context "multiple adjustments and the best one is not eligible" do
          let!(:promo_a) { create_adjustment("Promotion A", -100) }
          let!(:promo_c) { create_adjustment("Promotion C", -300) }

          before do
            promo_a.update_attribute_without_callbacks(:eligible, true)
            promo_c.update_attribute_without_callbacks(:eligible, false)
          end

          # regression for #3274
          it "still makes the previous best eligible adjustment valid" do
            updater.update_promotion_adjustments
            order.adjustments.eligible.promotion.first.label.should == 'Promotion A'
          end
        end

        it "should only leave one adjustment even if 2 have the same amount" do
          create_adjustment("Promotion A", -100)
          create_adjustment("Promotion B", -200)
          create_adjustment("Promotion C", -200)

          updater.update_promotion_adjustments

          order.adjustments.eligible.promotion.count.should == 1
          order.adjustments.eligible.promotion.first.amount.to_i.should == -200
        end

        it "should only include eligible adjustments in promo_total" do
          create_adjustment("Promotion A", -100)
          create(:adjustment, :adjustable => order,
                              :originator => nil,
                              :amount     => -1000,
                              :state      => "closed",
                              :eligible   => false,
                              :label      => 'Bad promo')

          order.promo_total.to_f.should == -100.to_f
        end
      end
    end
  end
end
