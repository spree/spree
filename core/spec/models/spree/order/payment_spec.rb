require 'spec_helper'

module Spree
  describe Spree::Order, :type => :model do
    let(:order) { stub_model(Spree::Order) }
    let(:updater) { Spree::OrderUpdater.new(order) }

    context "processing payments" do

      before do
        # So that Payment#purchase! is called during processing
        Spree::Config[:auto_capture] = true

        allow(order).to receive_message_chain(:line_items, :empty?).and_return(false)
        allow(order).to receive_messages :total => 100
      end

      it 'processes all payments' do
        payment_1 = create(:payment, :amount => 50)
        payment_2 = create(:payment, :amount => 50)
        allow(order).to receive(:pending_payments).and_return([payment_1, payment_2])

        order.process_payments!
        updater.update_payment_state
        expect(order.payment_state).to eq('paid')

        expect(payment_1).to be_completed
        expect(payment_2).to be_completed
      end

      it 'does not go over total for order' do
        payment_1 = create(:payment, :amount => 50)
        payment_2 = create(:payment, :amount => 50)
        payment_3 = create(:payment, :amount => 50)
        allow(order).to receive(:pending_payments).and_return([payment_1, payment_2, payment_3])

        order.process_payments!
        updater.update_payment_state
        expect(order.payment_state).to eq('paid')

        expect(payment_1).to be_completed
        expect(payment_2).to be_completed
        expect(payment_3).to be_checkout
      end

      it "does not use failed payments" do
        payment_1 = create(:payment, :amount => 50)
        payment_2 = create(:payment, :amount => 50, :state => 'failed')
        allow(order).to receive(:pending_payments).and_return([payment_1])

        expect(payment_2).not_to receive(:process!)

        order.process_payments!
      end
    end

    context "ensure source attributes stick around" do

      # For the reason of this test, please see spree/spree_gateway#132
      it "does not have inverse_of defined" do
        expect(Spree::Order.reflections[:payments].options[:inverse_of]).to be_nil
      end

      it "keeps source attributes after updating" do
        persisted_order = Spree::Order.create
        credit_card_payment_method = create(:credit_card_payment_method)
        attributes = {
          :payments_attributes => [
            {
              :payment_method_id => credit_card_payment_method.id,
              :source_attributes => {
                :name => "Ryan Bigg",
                :number => "41111111111111111111",
                :expiry => "01 / 15",
                :verification_value => "123"
              }
            }
          ]
        }

        persisted_order.update_attributes(attributes)
        expect(persisted_order.pending_payments.last.source.number).to be_present
      end
    end

    context "checking if order is paid" do
      context "payment_state is paid" do
        before { allow(order).to receive_messages payment_state: 'paid' }
        it { expect(order).to be_paid }
      end

      context "payment_state is credit_owned" do
        before { allow(order).to receive_messages payment_state: 'credit_owed' }
        it { expect(order).to be_paid }
      end
    end

    context "#process_payments!" do
      let(:payment) { stub_model(Spree::Payment) }

      before { allow(order).to receive_messages pending_payments: [payment], total: 10 }

      it "should process the payments" do
        expect(payment).to receive(:process!)
        expect(order.process_payments!).to be_truthy
      end

      # Regression spec for https://github.com/spree/spree/issues/5436
      it 'should raise an error if there are no payments to process' do
        allow(order).to receive_messages pending_payments: []
        expect(payment).to_not receive(:process!)
        expect(order.process_payments!).to be_falsey
      end

      context "when a payment raises a GatewayError" do
        before { expect(payment).to receive(:process!).and_raise(Spree::Core::GatewayError) }

        it "should return true when configured to allow checkout on gateway failures" do
          Spree::Config.set :allow_checkout_on_gateway_error => true
          expect(order.process_payments!).to be true
        end

        it "should return false when not configured to allow checkout on gateway failures" do
          Spree::Config.set :allow_checkout_on_gateway_error => false
          expect(order.process_payments!).to be false
        end
      end
    end

    context "#outstanding_balance" do
      it "should return positive amount when payment_total is less than total" do
        order.payment_total = 20.20
        order.total = 30.30
        expect(order.outstanding_balance).to eq(10.10)
      end
      it "should return negative amount when payment_total is greater than total" do
        order.total = 8.20
        order.payment_total = 10.20
        expect(order.outstanding_balance).to be_within(0.001).of(-2.00)
      end
    end

    context "#outstanding_balance?" do
      it "should be true when total greater than payment_total" do
        order.total = 10.10
        order.payment_total = 9.50
        expect(order.outstanding_balance?).to be true
      end
      it "should be true when total less than payment_total" do
        order.total = 8.25
        order.payment_total = 10.44
        expect(order.outstanding_balance?).to be true
      end
      it "should be false when total equals payment_total" do
        order.total = 10.10
        order.payment_total = 10.10
        expect(order.outstanding_balance?).to be false
      end
    end

    context "payment required?" do
      context "total is zero" do
        before { allow(order).to receive_messages(total: 0) }
        it { expect(order.payment_required?).to be false }
      end

      context "total > zero" do
        before { allow(order).to receive_messages(total: 1) }
        it { expect(order.payment_required?).to be true }
      end
    end
  end
end
