require 'spec_helper'

describe "Payment" do

  context "#cancel!" do

    subject do
      payment.cancel!
    end

    context "a store credit" do

      let(:store_credit) { create(:store_credit, amount_used: captured_amount) }
      let(:auth_code)    { "1-SC-20141111111111" }
      let(:captured_amount) { 10.0 }

      let!(:capture_event) { create(:store_credit_auth_event,
        action: Spree::StoreCredit::CAPTURE_ACTION,
        authorization_code: auth_code,
        amount: captured_amount,
        store_credit: store_credit) }

      let(:payment) { create(:store_credit_payment, response_code: auth_code) }

      it "attemps to cancels the payment" do
        payment.payment_method.should_receive(:cancel).with(payment.response_code)
        subject
      end

      context "cancels successfully" do
        it "voids the payment" do
          expect { subject }.to change{ payment.state }.to('void')
        end
      end

      context "does not cancel successfully" do
        it "does not change the payment state" do
          Spree::PaymentMethod::StoreCredit.any_instance.stub(:cancel).and_return(false)
          expect { subject }.to_not change{ payment.state }
        end
      end
    end

    context "not a store credit" do
      let(:payment) { create(:payment) }

      it "should call super" do
        payment.should_receive(:cancel!)
        subject
      end
    end
  end
end
