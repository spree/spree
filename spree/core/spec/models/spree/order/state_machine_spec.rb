require 'spec_helper'

# The checkout state machine is gone — these specs cover the machine-free
# order lifecycle: status flips with their side effects, and the
# cancellation guards.
describe Spree::Order, type: :model do
  let(:order) { create(:order) }

  describe '#allow_cancel?' do
    %w(unfulfilled backorder canceled).each do |fulfillment_status|
      it "is true when fulfillment_status is #{fulfillment_status}" do
        allow(order).to receive_messages completed?: true
        order.fulfillment_status = fulfillment_status
        expect(order.allow_cancel?).to be true
      end
    end

    %w(fulfilled partial delivered).each do |fulfillment_status|
      it "is false when fulfillment_status is #{fulfillment_status}" do
        allow(order).to receive_messages completed?: true
        order.fulfillment_status = fulfillment_status
        expect(order.allow_cancel?).to be false
      end
    end

    it 'is false for incomplete orders' do
      allow(order).to receive_messages completed?: false
      expect(order.allow_cancel?).to be false
    end
  end

  describe '#cancel / #resume' do
    let(:order) { create(:completed_order_with_pending_payment) }

    it 'flips status to canceled, cancels fulfillments and voids payments' do
      expect(order.cancel).to be true

      expect(order.reload.status).to eq('canceled')
      expect(order.canceled_at).to be_present
      expect(order.fulfillments.reload).to all(be_canceled)
      expect(order.payments.reload.map(&:state)).to all(be_in(%w[void invalid checkout]))
    end

    it 'refuses to cancel when not allowed' do
      order.fulfillments.each { |fulfillment| fulfillment.update_column(:status, 'fulfilled') }
      order.update_column(:fulfillment_status, 'fulfilled')

      expect(order.cancel).to be false
      expect { order.cancel! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'resumes a canceled order back to placed' do
      order.cancel!

      expect(order.resume).to be true
      expect(order.reload.status).to eq('placed')
      expect(order.fulfillments.reload.map(&:status)).to all(eq('unfulfilled'))
    end

    it 'refuses to resume a non-canceled order' do
      expect(order.resume).to be false
    end
  end

  describe '#canceled_by' do
    let(:order) { create(:completed_order_with_pending_payment) }
    let(:admin) { create(:admin_user) }

    it 'records the canceler and cancels through the service' do
      order.canceled_by(admin)

      expect(order.reload.status).to eq('canceled')
      expect(order.canceler_id).to eq(admin.id)
      expect(order.canceled_at).to be_present
    end
  end
end
