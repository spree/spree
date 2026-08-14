require 'spec_helper'

module Spree
  describe Fulfillments::Cancel do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store, line_items_count: 2) }
    let(:fulfillment) { order.fulfillments.first }

    let(:execute) { subject.call(fulfillment: fulfillment) }

    it 'cancels the fulfillment' do
      expect(execute.success?).to eq(true)
      expect(fulfillment.reload).to be_canceled
    end

    it 'puts the units back on the shelf' do
      variant = fulfillment.fulfillment_items.first.variant
      stock_level = fulfillment.stock_location.stock_level(variant)

      expect { execute }.to change { stock_level.reload.count_on_hand }.by(
        fulfillment.fulfillment_items.where(variant_id: variant.id).sum(:quantity)
      )
    end

    # Fulfillment#provider builds a fresh Manual provider per call, so the
    # double is injected rather than stubbed on an instance.
    let(:provider) { instance_double(Spree::FulfillmentProvider::Manual, cancel_fulfillment: true) }

    it 'tells the provider to stand down' do
      allow(fulfillment).to receive(:provider).and_return(provider)
      expect(provider).to receive(:cancel_fulfillment).with(fulfillment)

      subject.call(fulfillment: fulfillment)
    end

    # The whole reason this moved out of the transition callback: a slow or
    # failing carrier must not hold the stock movements' row locks, and must
    # not roll back a restock that already happened.
    it 'notifies the provider only after the restock has committed' do
      open_transactions = nil
      allow(fulfillment).to receive(:provider).and_return(provider)
      allow(provider).to receive(:cancel_fulfillment) do
        open_transactions = ApplicationRecord.connection.open_transactions
      end

      subject.call(fulfillment: fulfillment)

      # The suite wraps each example in a transaction, so "committed" here
      # means no transaction was opened beyond that outer one.
      expect(open_transactions).to eq(ApplicationRecord.connection.open_transactions)
    end

    it 'refuses a fulfillment that cannot cancel' do
      fulfillment.update!(status: 'fulfilled')

      result = subject.call(fulfillment: fulfillment)

      expect(result.success?).to eq(false)
      expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.cannot_cancel'))
      expect(fulfillment.reload).to be_fulfilled
    end

    describe 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'lets a validate handler veto before anything is written' do
        Spree.hooks.register('fulfillments.cancel.validate') { |flow| flow.reject!('already picked') }

        result = execute

        expect(result.success?).to eq(false)
        expect(result.error.to_s).to eq('already picked')
        expect(fulfillment.reload).not_to be_canceled
      end

      it 'runs after_cancel with the canceled fulfillment' do
        seen = nil
        Spree.hooks.register('fulfillments.cancel.after_cancel') { |flow| seen = flow.fulfillment }

        execute

        expect(seen).to eq(fulfillment)
      end
    end
  end
end
