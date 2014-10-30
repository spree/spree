require 'spec_helper'

module Spree
  describe Reimbursement::ReimbursementTypeValidator, :type => :model do
    class DummyClass
      include Spree::Reimbursement::ReimbursementTypeValidator

      class_attribute :expired_reimbursement_type
      self.expired_reimbursement_type = Spree::ReimbursementType::Credit

      class_attribute :refund_time_constraint
      self.refund_time_constraint = 90.days
    end

    let(:return_item) do
      create(
        :return_item,
        preferred_reimbursement_type: preferred_reimbursement_type
      )
    end
    let(:dummy) { DummyClass.new }
    let(:preferred_reimbursement_type) { Spree::ReimbursementType::Credit.new }

    describe '#valid_preferred_reimbursement_type?' do
      before do
        allow(dummy).to receive(:past_reimbursable_time_period?).and_return(true)
      end

      subject { dummy.valid_preferred_reimbursement_type?(return_item) }

      context 'is valid' do
        it 'if it is not past the reimbursable time period' do
          allow(dummy).to receive(:past_reimbursable_time_period?).and_return(false)
          expect(subject).to be true
        end

        it 'if the return items preferred method of reimbursement is the expired method of reimbursement' do
          expect(subject).to be true
        end
      end

      context 'is invalid' do
        it 'if the return item is past the eligible time period and the preferred method of reimbursement is not the expired method of reimbursement' do
          return_item.preferred_reimbursement_type =
            Spree::ReimbursementType::OriginalPayment.new
          expect(subject).to be false
        end
      end
    end

    describe '#past_reimbursable_time_period?' do
      subject { dummy.past_reimbursable_time_period?(return_item) }

      before do
        allow(return_item).to receive_message_chain(:inventory_unit, :shipment, :shipped_at).and_return(shipped_at)
      end

      context 'it has not shipped' do
        let(:shipped_at) { nil }

        it 'is not past the reimbursable time period' do
          expect(subject).to be_falsey
        end
      end

      context 'it has shipped and it is more recent than the time constraint' do
        let(:shipped_at) { (dummy.refund_time_constraint - 1.day).ago }

        it 'is not past the reimbursable time period' do
          expect(subject).to be false
        end
      end

      context 'it has shipped and it is further in the past than the time constraint' do
        let(:shipped_at) { (dummy.refund_time_constraint + 1.day).ago }

        it 'is past the reimbursable time period' do
          expect(subject).to be true
        end
      end
    end
  end
end
