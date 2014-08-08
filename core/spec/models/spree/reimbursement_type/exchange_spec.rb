require 'spec_helper'

module Spree
  describe ReimbursementType::Exchange do
    describe '.reimburse' do
      let(:reimbursement) { create(:reimbursement, return_items_count: 1) }
      let(:return_items)  { reimbursement.return_items }
      let(:new_exchange)  { double("Exchange") }
      let(:simulate)      { true }

      subject { Spree::ReimbursementType::Exchange.reimburse(reimbursement, return_items, simulate)}

      context 'return items are supplied' do
        before do
          Spree::Exchange.should_receive(:new).with(reimbursement.order, return_items).and_return(new_exchange)
        end

        context "simulate is true" do

          it 'does not perform an exchange and returns the exchange object' do
            new_exchange.should_not_receive(:perform!)
            expect(subject).to eq [new_exchange]
          end
        end

        context "simulate is false" do
          let(:simulate) { false }

          it 'performs an exchange and returns the exchange object' do
            new_exchange.should_receive(:perform!)
            expect(subject).to eq [new_exchange]
          end
        end
      end

      context "no return items are supplied" do
        let(:return_items) { [] }

        it 'does not perform an exchange and returns an empty array' do
          new_exchange.should_not_receive(:perform!)
          expect(subject).to eq []
        end
      end
    end
  end
end
