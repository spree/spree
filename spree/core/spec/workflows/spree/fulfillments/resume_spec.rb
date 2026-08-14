require 'spec_helper'

module Spree
  describe Fulfillments::Resume do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store, line_items_count: 2) }
    let(:fulfillment) { order.fulfillments.first }

    let(:execute) { subject.call(fulfillment: fulfillment) }

    before { fulfillment.update!(status: 'canceled') }

    it 'brings the fulfillment back' do
      expect(execute.success?).to eq(true)
      expect(fulfillment.reload).not_to be_canceled
    end

    it 'takes the units back off the shelf' do
      variant = fulfillment.fulfillment_items.first.variant
      stock_level = fulfillment.stock_location.stock_level(variant)

      expect { execute }.to change { stock_level.reload.count_on_hand }.by(
        -fulfillment.fulfillment_items.where(variant_id: variant.id).sum(:quantity)
      )
    end

    it 'refuses a fulfillment that is not canceled' do
      described_class.call(fulfillment: fulfillment)

      result = subject.call(fulfillment: fulfillment)

      expect(result.success?).to eq(false)
      expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.cannot_resume'))
    end

    describe 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'lets a validate handler veto before the stock moves' do
        Spree.hooks.register('fulfillments.resume.validate') { |flow| flow.reject!('stock sold on') }

        variant = fulfillment.fulfillment_items.first.variant
        stock_level = fulfillment.stock_location.stock_level(variant)

        expect { execute }.not_to change { stock_level.reload.count_on_hand }
        expect(fulfillment.reload).to be_canceled
      end

      it 'runs after_resume with the resumed fulfillment' do
        seen = nil
        Spree.hooks.register('fulfillments.resume.after_resume') { |flow| seen = flow.fulfillment }

        execute

        expect(seen).to eq(fulfillment)
      end
    end
  end
end
