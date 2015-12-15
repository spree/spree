require 'spec_helper'

describe Spree::ReimbursementType::Credit, type: :model do
  let(:reimbursement)          { create(:reimbursement, return_items_count: 1) }
  let(:return_item)            { reimbursement.return_items.first!             }
  let(:payment)                { reimbursement.order.payments.first!           }
  let(:simulate)               { false                                         }
  let!(:default_refund_reason) { create(:refund_reason)                        }

  # Anything with an #amount method does the job
  # Spree itself does NOT provide a creditable and the polymorphic
  # assoc is left an open end.
  #
  # Till we have time to nuke this antifeature
  # we use a payment to fullfill the contract of this method.
  let(:creditable) { create(:payment) }

  subject do
    Spree::ReimbursementType::Credit.reimburse(
      reimbursement,
      [return_item],
      simulate
    )
  end

  before do
    reimbursement.update!(total: reimbursement.calculated_total)

    allow(Spree::ReimbursementType::Credit)
      .to receive_messages(create_creditable: creditable)
  end

  describe '.reimburse' do
    context 'simulate is true' do
      let(:simulate) { true }

      it 'creates one readonly lump credit for all outstanding balance payable to the customer' do
        expect(subject.map(&:class)).to eql([Spree::Reimbursement::Credit])
        expect(subject.map(&:readonly?)).to eql([true])
        expect(subject.sum(&:amount)).to eql(reimbursement.return_items.to_a.sum(&:total))
      end

      it 'does not save to the database' do
        expect { subject }.to_not change { Spree::Reimbursement::Credit.count }
      end
    end

    context 'simulate is false' do
      let(:simulate) { false }

      it 'creates one lump credit for all outstanding balance payable to the customer' do
        expect { subject }
          .to change { Spree::Reimbursement::Credit.count }
          .from(0)
          .to(1)
        expect(subject.sum(&:amount)).to eql(reimbursement.return_items.to_a.sum(&:total))
      end
    end
  end
end
