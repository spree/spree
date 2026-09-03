require 'spec_helper'

RSpec.describe Spree::SellerTransfers::Create do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }

  # A shipped seller order worth 100, on which the marketplace charged 12
  # including the VAT it charges the seller on its fee.
  def shipped_order(total: 100, commission: 12, tax_remittance: 'seller', tax: 0, included_tax: 0)
    order = create(:order, store: store, seller: seller)
    line_item = create(:line_item, order: order)
    create(:fulfillment, order: order, cart: nil, status: 'fulfilled')
    seller.update!(tax_remittance: tax_remittance)

    if commission.positive?
      create(:commission_line, order: order, seller: seller, line_item: line_item,
                               amount: commission, tax_amount: 0, total: commission, currency: order.currency)
    end

    # Written last and directly: the workflow reads the order's own totals, and
    # letting recalculation derive them from the factory's line items would be
    # testing the totals workflow rather than the ledger.
    order.update_columns(total: total, additional_tax_total: tax, included_tax_total: included_tax,
                         status: 'placed', completed_at: Time.current)

    order.reload
  end

  describe 'what the seller earned' do
    it 'is the sale less what the marketplace charged them' do
      result = described_class.call(order: shipped_order)

      expect(result).to be_success
      expect(result.value.amount).to eq(88)
    end

    it 'credits nothing below zero when commission outruns the sale' do
      result = described_class.call(order: shipped_order(total: 10, commission: 40))

      expect(result.value.amount).to eq(0)
    end

    # The marketplace files the consumer tax under facilitator rules, so it is
    # never the seller's to receive.
    it 'withholds consumer tax from a platform-remitted seller' do
      result = described_class.call(order: shipped_order(total: 100, commission: 12, tax_remittance: 'platform', tax: 20))

      expect(result.value.amount).to eq(68)
    end

    # A market quoting gross prices keeps the tax inside the order total
    # rather than adding it on top, so subtracting only the added half would
    # pay the seller VAT the marketplace is about to remit.
    it 'withholds tax that was included in the price, not added to it' do
      result = described_class.call(
        order: shipped_order(total: 100, commission: 12, tax_remittance: 'platform', included_tax: 20)
      )

      expect(result.value.amount).to eq(68)
    end

    it 'leaves consumer tax with a seller who remits it themselves' do
      result = described_class.call(order: shipped_order(total: 100, commission: 12, tax: 20))

      expect(result.value.amount).to eq(88)
    end
  end

  describe 'what it refuses to credit' do
    it 'ignores the operator’s own order' do
      order = create(:order, store: store, status: 'placed', completed_at: Time.current)
      create(:fulfillment, order: order, cart: nil, status: 'fulfilled')

      expect { described_class.call(order: order.reload) }.not_to change { Spree::SellerTransfer.count }
    end

    it 'ignores an order whose goods have not gone out' do
      order = create(:order, store: store, seller: seller, total: 50)
      create(:fulfillment, order: order, cart: nil, status: 'unfulfilled')

      expect { described_class.call(order: order.reload) }.not_to change { Spree::SellerTransfer.count }
    end

    # fully_fulfilled? answers true for an order with no fulfillments, since
    # none of nothing is outstanding — which must not read as shipped.
    it 'ignores an order with nothing to fulfil' do
      order = create(:order, store: store, seller: seller, total: 50)

      expect { described_class.call(order: order) }.not_to change { Spree::SellerTransfer.count }
    end
  end

  # A seller whose account is still being verified has earned all the same.
  # `order.fulfilled` fires once and nothing re-drives it, so refusing to
  # write the row would lose the earning outright.
  describe 'when the provider cannot pay the seller yet' do
    before do
      allow_any_instance_of(Spree::PayoutProvider::System).to receive(:requires_payout_account?).and_return(true)
      allow(Spree::PayoutProvider::System).to receive(:requires_payout_account?).and_return(true)
    end

    it 'still records what they earned' do
      expect { described_class.call(order: shipped_order) }.to change { Spree::SellerTransfer.count }.by(1)
    end

    it 'leaves it pending rather than claiming the money moved' do
      expect(described_class.call(order: shipped_order).value).to be_pending
    end

    it 'never asks the provider to send it' do
      expect_any_instance_of(Spree::PayoutProvider::System).not_to receive(:transfer!)

      described_class.call(order: shipped_order)
    end
  end

  describe 'replay' do
    it 'returns the earning that exists rather than crediting twice' do
      order = shipped_order
      first = described_class.call(order: order).value

      second = described_class.call(order: order.reload)

      expect(second.value.id).to eq(first.id)
      expect(Spree::SellerTransfer.count).to eq(1)
    end
  end

  describe 'with the record-only provider' do
    it 'confirms the earning immediately, since nothing has to be sent' do
      result = described_class.call(order: shipped_order)

      expect(result.value).to be_completed
      expect(result.value.provider).to eq('Spree::PayoutProvider::System')
    end

    it 'counts toward the seller’s balance' do
      described_class.call(order: shipped_order)

      expect(seller.balance('USD')).to eq(88)
    end
  end

  # The two ways a provider call can go wrong want opposite reactions, so they
  # must not share a status: one is owed and should be tried again, the other
  # may already have been sent and must not be.
  describe 'when the provider call goes wrong' do
    before { seller.update!(payouts_enabled_at: Time.current) }

    context 'and the provider refused outright' do
      before do
        allow_any_instance_of(Spree::PayoutProvider::System).to receive(:transfer!).
          and_raise(StandardError, 'gateway down')
      end

      it 'leaves the earning for the retry job to send' do
        result = described_class.call(order: shipped_order)

        expect(result.value.reload).to be_processing
      end
    end

    context 'and nobody knows whether the money moved' do
      before do
        allow_any_instance_of(Spree::PayoutProvider::System).to receive(:transfer!).
          and_raise(Spree::Core::AmbiguousGatewayError, 'connection timed out')
      end

      it 'parks it where no automatic attempt will send it again' do
        result = described_class.call(order: shipped_order)

        expect(result.value.reload).to be_unresolved
      end

      # The retry job takes pending and processing rows, and an idempotency
      # key stops a duplicate only while the provider still holds the record.
      it 'is not picked up by the job that retries earnings' do
        described_class.call(order: shipped_order)

        retryable = seller.seller_transfers.earnings.where(status: %w[pending processing], payout_id: nil)

        expect(retryable).to be_empty
      end

      it 'stays out of the balance until somebody establishes what happened' do
        described_class.call(order: shipped_order)

        expect(seller.balance('USD')).to eq(0)
      end
    end
  end
end
