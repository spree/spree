require 'spec_helper'

module Spree
  describe Reimbursement::Credit, type: :model do
    context 'class methods' do
      describe '.total_amount_reimbursed_for' do
        subject { Spree::Reimbursement::Credit.total_amount_reimbursed_for(reimbursement) }

        let(:reimbursement) { create(:reimbursement) }
        let(:credit_double) { double(amount: 99.99) }

        before { allow(reimbursement).to receive(:credits).and_return([credit_double, credit_double]) }

        it 'sums the amounts of all of the reimbursements credits' do
          expect(subject).to eq BigDecimal('199.98')
        end
      end
    end

    describe '#description' do
      let(:credit) { Spree::Reimbursement::Credit.new(amount: 100, creditable: mock_model(Spree::PaymentMethod::Check)) }

      it "is the creditable's class name" do
        expect(credit.description).to eq 'Check'
      end
    end

    describe '#display_amount' do
      let(:credit) { Spree::Reimbursement::Credit.new(amount: 100) }

      it 'is a money object' do
        expect(credit.display_amount).to eq Spree::Money.new(100, currency: 'USD')
      end
    end
  end
end
