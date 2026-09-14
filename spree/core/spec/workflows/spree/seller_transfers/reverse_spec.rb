require 'spec_helper'

RSpec.describe Spree::SellerTransfers::Reverse do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:order) { create(:order, store: store, seller: seller, total: 100) }

  def earn(amount = 80)
    create(:seller_transfer, :completed, seller: seller, order: order, amount: amount)
  end

  describe 'taking money back' do
    it 'writes a negative row rather than editing the earning' do
      earning = earn

      result = described_class.call(order: order, amount: 30)

      expect(result).to be_success
      expect(earning.reload.amount).to eq(80)
    end

    # A refund is the customer's gross figure; the seller only ever received
    # their net cut, so taking the gross back would charge them the
    # marketplace's commission on goods that came back.
    it 'takes back only the seller’s share of what was refunded' do
      earn

      # 30 refunded on a 100 order that earned the seller 80.
      expect(described_class.call(order: order, amount: 30).value.amount).to eq(-24)
    end

    it 'leaves the seller with what is left' do
      earn
      described_class.call(order: order, amount: 30)

      expect(seller.balance('USD')).to eq(56)
    end

    it 'links the reversal to what it reverses' do
      earning = earn

      expect(described_class.call(order: order, amount: 30).value.reversed_from).to eq(earning)
    end
  end

  # The blend above is only right when every part of the order earned the seller
  # the same proportion. It never does: commission excludes shipping, so goods
  # earn 90% and delivery 100%. A refund that names the units it paid for can be
  # answered exactly instead.
  describe 'when the refund names the lines it paid for' do
    let(:order) { create(:shipped_order, store: store, seller: seller, line_items_count: 1, line_items_price: 18) }
    let(:line_item) { order.line_items.first }
    let(:return_record) { create(:received_return, order: order, store: store) }
    let(:refund) { create(:refund, amount: 18, originator: return_record) }

    before { create(:commission_line, order: order, seller: seller, line_item: line_item, amount: 1.8, total: 1.8) }

    # 18.00 of goods less the 1.80 charged on them. The blend would have taken
    # 18.00 x (earning / order total), dipping into the delivery as well.
    it 'takes back what the returned units earned, not a slice of the whole order' do
      earn(order.total - 1.8)

      expect(described_class.call(order: order, amount: 18, refund: refund).value.amount).to eq(-16.2)
    end

    it 'leaves the seller the delivery the customer was never refunded' do
      earn(order.total - 1.8)
      described_class.call(order: order, amount: 18, refund: refund)

      expect(seller.balance('USD')).to eq(order.delivery_total)
    end

    it 'ignores a line the customer announced but never sent back' do
      return_record.return_line_items.each { |line| line.update!(received_quantity: 0) }
      earn(order.total - 1.8)

      # Nothing came back, so nothing is attributable and the order's own ratio
      # answers instead — which is the figure that dips into the delivery.
      blended = (18 * ((order.total - 1.8) / order.total)).round(2)

      expect(described_class.call(order: order, amount: 18, refund: refund).value.amount).to eq(-blended)
    end

    context 'when only part of a line comes back' do
      before do
        line_item.update!(price: 24, quantity: 3)
        Spree::CommissionLine.for_line_items.update_all(amount: 7.2, total: 7.2)
      end

      # One of three units: 24.00 of goods less its third of the 7.20 charged
      # on the line.
      it 'takes back that unit’s share of the line' do
        earn(order.total - 7.2)

        expect(described_class.call(order: order, amount: 24, refund: refund).value.amount).to eq(-21.6)
      end
    end

    # One return is refunded once per payment it draws on, and every one of
    # those refunds names the same lines. Taken at face value they would each
    # claw back the whole thing.
    it 'splits one clawback across the refunds a single return produced' do
      earn(order.total - 1.8)
      first = create(:refund, amount: 10, originator: return_record)
      second = create(:refund, amount: 8, originator: return_record)

      described_class.call(order: order, amount: 10, refund: first)
      described_class.call(order: order, amount: 8, refund: second)

      expect(Spree::SellerTransfer.reversals_only.sum(:amount)).to eq(-16.2)
    end

    it 'scales when the operator refunded something other than what the units are worth' do
      earn(order.total - 1.8)

      # Half of what came back is worth, so half of what it earned.
      expect(described_class.call(order: order, amount: 9, refund: refund).value.amount).to eq(-8.1)
    end

    context 'when the marketplace remits the consumer tax' do
      before do
        seller.update!(tax_remittance: 'platform')
        line_item.update!(additional_tax_total: 2)
      end

      # The seller never received the tax, so it is not theirs to give back.
      it 'takes the tax off the attributed lines too' do
        earn(order.total - 1.8)

        expect(described_class.call(order: order, amount: 18, refund: refund).value.amount).to eq(-14.2)
      end
    end
  end

  describe 'when the refund names nothing' do
    # A cancellation and a manual refund carry no originator, so there is
    # nothing to attribute and the order's own ratio is the best answer.
    it 'falls back to the order’s ratio' do
      earn(80)

      expect(described_class.call(order: order, amount: 30, refund: create(:refund, amount: 30)).value.amount).
        to eq(-24)
    end
  end

  # Payouts are swept by settlement currency. A clawback left in the sale's
  # currency would never join the batch paying the earning it cancels.
  describe 'when the earning settled in another currency' do
    it 'takes the money back where the earning landed' do
      create(:seller_transfer, :completed, seller: seller, order: order, amount: 80,
                                           settled_amount: 60, settled_currency: 'GBP')

      reversal = described_class.call(order: order, amount: 30).value

      expect(reversal.settled_currency).to eq('GBP')
      expect(reversal.currency).to eq('USD')
    end

    # 30 refunded on a 100 order that earned 80 claws back 24, which at the rate
    # that earning actually settled at is 18 of the 60 that arrived.
    it 'claws back at the rate the money went out at' do
      create(:seller_transfer, :completed, seller: seller, order: order, amount: 80,
                                           settled_amount: 60, settled_currency: 'GBP')

      expect(described_class.call(order: order, amount: 30).value.settled_amount).to eq(-18)
    end

    # Nothing converted, so the clawback settles as it was sold — the same
    # figure, in the same currency, which is what the built-in provider always
    # produces.
    it 'settles as it was sold when nothing was converted' do
      earn(80)

      reversal = described_class.call(order: order, amount: 30).value

      expect(reversal.settled_amount).to eq(-24)
      expect(reversal.settled_currency).to eq('USD')
      expect(reversal).not_to be_converted
    end
  end

  describe 'what it will not take back' do
    it 'refuses to claw back more than was credited' do
      earn(80)

      expect(described_class.call(order: order, amount: 200).value.amount).to eq(-80)
    end

    it 'takes nothing once the earning is fully reversed' do
      earn(80)
      # The whole order refunded takes the whole earning back.
      described_class.call(order: order, amount: 100)

      expect { described_class.call(order: order, amount: 20) }.
        not_to change { Spree::SellerTransfer.count }
    end

    # An order refunded before it shipped never credited anybody.
    it 'does nothing when there was no earning' do
      expect { described_class.call(order: order, amount: 30) }.
        not_to change { Spree::SellerTransfer.count }
    end
  end

  # A subscriber job retries on error, so the same refund can be handled more
  # than once. Without a key tying a reversal to its cause, each attempt would
  # take the money back again.
  describe 'when the same refund arrives twice' do
    let(:refund) { create(:refund, amount: 30) }

    it 'takes the money back once' do
      earn(80)
      described_class.call(order: order, amount: 30, refund: refund)

      expect { described_class.call(order: order, amount: 30, refund: refund) }.
        not_to change { Spree::SellerTransfer.count }

      expect(seller.balance('USD')).to eq(56)
    end

    it 'answers with the reversal that was already written' do
      earn(80)
      first = described_class.call(order: order, amount: 30, refund: refund).value

      expect(described_class.call(order: order, amount: 30, refund: refund).value).to eq(first)
    end

    # The read guard is not enough on its own — two deliveries can pass it
    # together — so the database has the last word.
    it 'refuses a second row even when the read guard is bypassed' do
      earning = earn(80)

      expect do
        Spree::SellerTransfer.create!(
          store: store, seller: seller, order: order, reversed_from: earning, refund: refund,
          amount: -30, currency: 'USD', kind: 'refund_reversal', provider: 'system', status: 'pending'
        )
        Spree::SellerTransfer.create!(
          store: store, seller: seller, order: order, reversed_from: earning, refund: refund,
          amount: -30, currency: 'USD', kind: 'refund_reversal', provider: 'system', status: 'pending'
        )
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'when two different refunds land on one order' do
    it 'never takes back more than was credited between them' do
      earn(80)

      described_class.call(order: order, amount: 60, refund: create(:refund, amount: 30))
      described_class.call(order: order, amount: 60, refund: create(:refund, amount: 30))

      # Two 60 refunds on a 100 order: 48 each against an 80 earning, floored
      # at what was credited.
      expect(seller.balance('USD')).to eq(0)
      expect(Spree::SellerTransfer.reversals_only.sum(:amount)).to eq(-80)
    end
  end

  # Money sits with whoever moved it. A marketplace that changes provider
  # still has to reverse the old one's transfer through the old one — asking
  # the new provider to undo something it never did leaves the original
  # standing, and the seller keeps a refunded sale.
  describe 'when the store changed provider after the earning' do
    let(:previous) do
      Class.new(Spree::PayoutProvider::Base) do
        def self.name = 'TestPreviousPayoutProvider'

        def reverse!(seller_transfer)
          seller_transfer.update!(status: 'completed', reference: 'reversed-by-previous')
          seller_transfer
        end
      end
    end

    before do
      stub_const('TestPreviousPayoutProvider', previous)
      allow(Spree).to receive(:payout_providers).and_return([Spree::PayoutProvider::System, previous])
    end

    it 'reverses through the provider that made the earning' do
      create(:seller_transfer, :completed, seller: seller, order: order, amount: 80,
                                           provider: 'TestPreviousPayoutProvider')

      reversal = described_class.call(order: order, amount: 30).value

      expect(reversal.reference).to eq('reversed-by-previous')
    end
  end

  # A provider that is no longer installed still holds the transfer. Handing
  # the reversal to whichever one the store uses now would mark the row
  # reversed while the money stayed where it was.
  describe 'when the provider that made the earning is gone' do
    it 'refuses rather than reversing through somebody else' do
      create(:seller_transfer, :completed, seller: seller, order: order, amount: 80,
                                           provider: 'SpreeGone::PayoutProvider')

      result = described_class.call(order: order, amount: 30)

      expect(result).to be_failure
    end

    it 'leaves the row for an operator to see' do
      create(:seller_transfer, :completed, seller: seller, order: order, amount: 80,
                                           provider: 'SpreeGone::PayoutProvider')

      described_class.call(order: order, amount: 30)

      expect(Spree::SellerTransfer.reversals_only.last).to be_processing
    end
  end

  # A settlement that has happened is never rewritten: the reversal is simply
  # unsettled, so the next sweep nets it off what comes after.
  describe 'when the earning was already settled' do
    it 'leaves the closed payout alone and waits for the next one' do
      payout = create(:seller_payout, :completed, seller: seller, amount: 80)
      create(:seller_transfer, :completed, seller: seller, order: order, amount: 80, payout: payout)

      reversal = described_class.call(order: order, amount: 30).value

      expect(payout.reload.amount).to eq(80)
      expect(reversal.payout).to be_nil
    end
  end
end
