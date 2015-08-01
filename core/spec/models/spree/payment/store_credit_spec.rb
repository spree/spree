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

      xit "attemps to cancels the payment" do
        expect(payment.payment_method).to receive(:cancel).with(payment.response_code)
        subject
      end

      context "cancels successfully" do
        xit "voids the payment" do
          expect { subject }.to change{ payment.state }.to('void')
        end
      end

      context "does not cancel successfully" do
        xit "does not change the payment state" do
          allow_any_instance_of(Spree::PaymentMethod::StoreCredit).to receive(:cancel).and_return(false)
          expect { subject }.to_not change{ payment.state }
        end
      end
    end
  end
end
