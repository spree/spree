require 'spec_helper'

describe Spree::Order, :type => :model do
  let(:order) { stub_model('Spree::Order') }

  describe ".is_risky?" do
    context "Not risky order" do
      let(:order) { FactoryGirl.create(:order, payments: [payment]) }
      context "with avs_response == D" do
        let(:payment) { FactoryGirl.create(:payment, avs_response: "D") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with avs_response == M" do
        let(:payment) { FactoryGirl.create(:payment, avs_response: "M") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with avs_response == ''" do
        let(:payment) { FactoryGirl.create(:payment, avs_response: "") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with cvv_response_code == M" do
        let(:payment) { FactoryGirl.create(:payment, cvv_response_code: "M") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with cvv_response_message == ''" do
        let(:payment) { FactoryGirl.create(:payment, cvv_response_message: "") }
        it "is not considered risky" do
          expect(order.is_risky?).to eq(false)
        end
      end
    end

    context "Risky order" do
      context "AVS response message" do
        let(:order) { FactoryGirl.create(:order, payments: [FactoryGirl.create(:payment, avs_response: "A")]) }
        it "returns true if the order has an avs_response" do
          expect(order.is_risky?).to eq(true)
        end
      end

      context "CVV response code" do
        let(:order) { FactoryGirl.create(:order, payments: [FactoryGirl.create(:payment, cvv_response_code: "N")]) }
        it "returns true if the order has an cvv_response_code" do
          expect(order.is_risky?).to eq(true)
        end
      end

      context "state == 'failed'" do
        let(:order) { FactoryGirl.create(:order, payments: [FactoryGirl.create(:payment, state: 'failed')]) }
        it "returns true if the order has state == 'failed'" do
          expect(order.is_risky?).to eq(true)
        end
      end
    end
  end

  context "is considered risky" do
    let(:order) do
      order = FactoryGirl.create(:completed_order_with_pending_payment)
      order.considered_risky!
      order
    end

    it "can be approved by a user" do
      expect(order).to receive(:approve!)
      order.approved_by(stub_model(Spree::LegacyUser, id: 1))
      expect(order.approver_id).to eq(1)
      expect(order.approved_at).to be_present
      expect(order.approved?).to be true
    end
  end
end
