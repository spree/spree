require 'spec_helper'

describe Spree::Order, type: :model do
  let(:order) { Spree::Order.new }
  before do
    # Ensure state machine has been re-defined correctly
    Spree::Order.define_state_machine!
    # We don't care about this validation here
    allow(order).to receive(:require_email)
  end

  context "#next!" do
    context "when current state is confirm" do
      before do
        order.state = "confirm"
        order.run_callbacks(:create)
        allow(order).to receive_messages payment_required?: true
        allow(order).to receive_messages process_payments!: true
        allow(order).to receive :has_available_shipment
      end

      context "when payment processing succeeds" do
        before do
          order.payments << FactoryGirl.create(:payment, state: 'checkout', order: order)
          allow(order).to receive_messages process_payments: true
        end

        it "should finalize order when transitioning to complete state" do
          expect(order).to receive(:finalize!)
          order.next!
        end

        context "when credit card processing fails" do
          before { allow(order).to receive_messages process_payments!: false }

          it "should not complete the order" do
            order.next
            expect(order.state).to eq("confirm")
          end
        end
      end

      context "when payment processing fails" do
        before { allow(order).to receive_messages process_payments!: false }

        it "cannot transition to complete" do
          order.next
          expect(order.state).to eq("confirm")
        end
      end
    end

    context "when current state is delivery" do
      before do
        allow(order).to receive_messages payment_required?: true
        allow(order).to receive :apply_free_shipping_promotions
        order.state = "delivery"
      end

      it "adjusts tax rates when transitioning to delivery" do
        # Once for the line items
        expect(Spree::TaxRate).to receive(:adjust).once
        allow(order).to receive :set_shipments_cost
        order.next!
      end

      it "adjusts tax rates twice if there are any shipments" do
        # Once for the line items, once for the shipments
        order.shipments.build stock_location: create(:stock_location)
        expect(Spree::TaxRate).to receive(:adjust).twice
        allow(order).to receive :set_shipments_cost
        order.next!
      end
    end
  end

  context "#can_cancel?" do
    %w(pending backorder ready).each do |shipment_state|
      it "should be true if shipment_state is #{shipment_state}" do
        allow(order).to receive_messages completed?: true
        order.shipment_state = shipment_state
        expect(order.can_cancel?).to be true
      end
    end

    (Spree::Shipment.state_machine.states.keys - [:pending, :backorder, :ready]).each do |shipment_state|
      it "should be false if shipment_state is #{shipment_state}" do
        allow(order).to receive_messages completed?: true
        order.shipment_state = shipment_state
        expect(order.can_cancel?).to be false
      end
    end
  end

  context "#cancel" do
    let!(:variant) { stub_model(Spree::Variant) }
    let!(:inventory_units) { [stub_model(Spree::InventoryUnit, variant: variant),
                              stub_model(Spree::InventoryUnit, variant: variant)] }
    let!(:shipment) do
      shipment = stub_model(Spree::Shipment)
      allow(shipment).to receive_messages inventory_units: inventory_units, order: order
      allow(order).to receive_messages shipments: [shipment]
      shipment
    end

    before do
      2.times do
        create(:line_item, order: order, price: 10)
      end

      allow(order.line_items).to receive_messages find_by_variant_id: order.line_items.first

      allow(order).to receive_messages completed?: true
      allow(order).to receive_messages allow_cancel?: true

      shipments = [shipment]
      allow(order).to receive_messages shipments: shipments
      allow(shipments).to receive_messages states: []
      allow(shipments).to receive_messages ready: []
      allow(shipments).to receive_messages pending: []
      allow(shipments).to receive_messages shipped: []

      allow_any_instance_of(Spree::OrderUpdater).to receive(:update_adjustment_total) { 10 }
    end

    it "should send a cancel email" do
      # Stub methods that cause side-effects in this test
      allow(shipment).to receive(:cancel!)
      allow(order).to receive :has_available_shipment
      allow(order).to receive :restock_items!
      mail_message = double "Mail::Message"
      order_id = nil
      expect(Spree::OrderMailer).to receive(:cancel_email) { |*args|
        order_id = args[0]
        mail_message
      }
      expect(mail_message).to receive :deliver_later
      order.cancel!
      expect(order_id).to eq(order.id)
    end

    context "restocking inventory" do
      before do
        allow(shipment).to receive(:ensure_correct_adjustment)
        allow(shipment).to receive(:update_order)
        allow(Spree::OrderMailer).to receive(:cancel_email).and_return(mail_message = double)
        allow(mail_message).to receive :deliver

        allow(order).to receive :has_available_shipment
      end
    end

    context "resets payment state" do
      let(:payment) { create(:payment, amount: order.total) }

      before do
        # TODO: This is ugly :(
        # Stubs methods that cause unwanted side effects in this test
        allow(Spree::OrderMailer).to receive(:cancel_email).and_return(mail_message = double)
        allow(mail_message).to receive :deliver_later
        allow(order).to receive :has_available_shipment
        allow(order).to receive :restock_items!
        allow(shipment).to receive(:cancel!)
        allow(payment).to receive(:cancel!)
        allow(order).to receive_message_chain(:payments, :valid, :size).and_return(1)
        allow(order).to receive_message_chain(:payments, :completed).and_return([payment])
        allow(order).to receive_message_chain(:payments, :completed, :includes).and_return([payment])
        allow(order).to receive_message_chain(:payments, :last).and_return(payment)
      end

      context "without shipped items" do
        it "should set payment state to 'void'" do
          expect { order.cancel! }.to change{ order.reload.payment_state }.to("void")
        end
      end

      context "with shipped items" do
        before do
          allow(order).to receive_messages shipment_state: 'partial'
          allow(order).to receive_messages outstanding_balance?: false
          allow(order).to receive_messages payment_state: "paid"
        end

        it "should not alter the payment state" do
          order.cancel!
          expect(order.payment_state).to eql "paid"
        end
      end

      context "with payments" do
        let(:payment) { create(:payment) }

        it "should automatically refund all payments" do
          allow(order).to receive_message_chain(:payments, :valid, :size).and_return(1)
          allow(order).to receive_message_chain(:payments, :completed).and_return([payment])
          allow(order).to receive_message_chain(:payments, :completed, :includes).and_return([payment])
          allow(order).to receive_message_chain(:payments, :last).and_return(payment)
          expect(payment).to receive(:cancel!)
          order.cancel!
        end
      end
    end
  end

  # Another regression test for #729
  context "#resume" do
    before do
      allow(order).to receive_messages email: "user@spreecommerce.com"
      allow(order).to receive_messages state: "canceled"
      allow(order).to receive_messages allow_resume?: true

      # Stubs method that cause unwanted side effects in this test
      allow(order).to receive :has_available_shipment
    end
  end
end
