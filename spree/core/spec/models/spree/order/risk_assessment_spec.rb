require 'spec_helper'

describe Spree::Order, type: :model do
  let(:order) { create(:order) }

  describe '.is_risky?' do
    context 'Not risky order' do
      let(:order) { FactoryBot.create(:order, payments: [payment]) }

      context 'with avs_response == D' do
        let(:payment) { FactoryBot.create(:payment, avs_response: 'D') }

        it 'is not considered risky' do
          expect(order.is_risky?).to eq(false)
        end
      end

      context 'with avs_response == M' do
        let(:payment) { FactoryBot.create(:payment, avs_response: 'M') }

        it 'is not considered risky' do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with avs_response == ''" do
        let(:payment) { FactoryBot.create(:payment, avs_response: '') }

        it 'is not considered risky' do
          expect(order.is_risky?).to eq(false)
        end
      end

      context 'with cvv_response_code == M' do
        let(:payment) { FactoryBot.create(:payment, cvv_response_code: 'M') }

        it 'is not considered risky' do
          expect(order.is_risky?).to eq(false)
        end
      end

      context "with cvv_response_message == ''" do
        let(:payment) { FactoryBot.create(:payment, cvv_response_message: '') }

        it 'is not considered risky' do
          expect(order.is_risky?).to eq(false)
        end
      end
    end

    context 'Risky order' do
      context 'AVS response message' do
        let(:order) { FactoryBot.create(:order, payments: [FactoryBot.create(:payment, avs_response: 'A')]) }

        it 'returns true if the order has an avs_response' do
          expect(order.is_risky?).to eq(true)
        end
      end

      context 'CVV response code' do
        let(:order) { FactoryBot.create(:order, payments: [FactoryBot.create(:payment, cvv_response_code: 'N')]) }

        it 'returns true if the order has an cvv_response_code' do
          expect(order.is_risky?).to eq(true)
        end
      end

      context "state == 'failed'" do
        let(:order) { FactoryBot.create(:order, payments: [FactoryBot.create(:payment, status: 'failed')]) }

        it "returns true if the order has state == 'failed'" do
          expect(order.is_risky?).to eq(true)
        end
      end
    end
  end

  context 'is considered risky' do
    # Clearing a risk hold is staff work, so the approver is an actor — a
    # member of staff or an API key — never the customer who placed it.
    let(:approver) { create(:admin_user) }
    let(:order) do
      order = FactoryBot.create(:completed_order_with_pending_payment)
      order.considered_risky!
      order
    end

    it 'can be approved by a member of staff' do
      order.approved_by(approver)
      order.reload
      expect(order.approver).to eq approver
      expect(order.approver_type).to eq Spree.admin_user_class.to_s
      expect(order.approved_at).to be_present
      expect(order.approved?).to be true
      expect(order.considered_risky).to be false
    end

    it 'refuses a customer, who is not an actor' do
      expect { order.approved_by(create(:customer)) }.
        to raise_error(ArgumentError, /not a registered actor class/)
    end
  end
end
