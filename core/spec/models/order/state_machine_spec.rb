require 'spec_helper'

describe Spree::Order do
  let(:order) { Spree::Order.new }
  before do
    # We don't care about this validation here
    order.stub(:require_email)
  end

  context "#next!" do
    context "when current state is confirm" do
      before { order.state = "confirm" }
      it "should finalize order when transitioning to complete state" do
        order.run_callbacks(:create)
        order.should_receive(:finalize!)
        order.next!
      end

       context "when credit card payment fails" do
         before do
           order.stub(:process_payments!).and_raise(Spree::Core::GatewayError)
         end

         context "when not configured to allow failed payments" do
            before do
              Spree::Config.set :allow_checkout_on_gateway_error => false
            end

            it "should not complete the order" do
               order.next
               order.state.should == "confirm"
             end
          end

         context "when configured to allow failed payments" do
           before do
             Spree::Config.set :allow_checkout_on_gateway_error => true
           end

           it "should complete the order" do
             pending
              order.next
              order.state.should == "complete"
            end

         end

       end
    end

    context "when current state is address" do
      before do
        order.stub(:has_available_payment)
        order.state = "address"
      end

      it "adjusts tax rates when transitioning to delivery" do
        Spree::TaxRate.should_receive :adjust
        order.next!
      end
    end

    context "when current state is delivery" do
      before do
        order.state = "delivery"
        order.stub :total => 10.0
      end

      context "when transitioning to payment state" do
        it "should create a shipment" do
          order.should_receive(:has_available_shipment)
          order.should_receive(:create_shipment!)
          order.next!
          order.state.should == 'payment'
        end
      end
    end

  end
end
