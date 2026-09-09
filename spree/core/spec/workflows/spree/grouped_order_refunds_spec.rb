require 'spec_helper'

# A marketplace basket is taken with one charge against the order group, so a
# child order holds no payments of its own — only its share of the group's.
# Every post-sale workflow that gives money back has to refund through that
# share: reading `order.payments` finds nothing, and measuring against the
# whole payment lets one seller's refund spend a sibling's captured money.
RSpec.describe 'refunding a child order of a split checkout' do
  let(:store) { @default_store }
  let(:group) { create(:order_group, store: store) }

  # Two sellers' orders under one group, each paid for by its own share of a
  # single completed payment. Created before the payment, whose amount the
  # group's own total bounds.
  let!(:order) { grouped_order(number_suffix: 1) }
  let!(:sibling) { grouped_order(number_suffix: 2) }

  let!(:payment) do
    create(:payment, order: nil, cart: nil, order_group: group, amount: 200, status: 'completed')
  end

  let!(:split) do
    create(:payment_split, payment: payment, order: order,
                           authorized_amount: 100, captured_amount: 100)
  end
  let!(:sibling_split) do
    create(:payment_split, payment: payment, order: sibling,
                           authorized_amount: 100, captured_amount: 100)
  end

  def grouped_order(number_suffix:)
    create(:shipped_order, store: store, line_items_count: 1).tap do |placed|
      placed.update_columns(order_group_id: group.id, number: "#{group.number}-#{number_suffix}")
      placed.reload
      group.orders.reload
    end
  end

  # The gateway is not the subject here — that a refund row is written against
  # the right share is.
  before do
    allow_any_instance_of(Spree::Refund).to receive(:perform!).and_return(true)
    allow_any_instance_of(Spree::Order).to receive(:tax_provider).
      and_return(instance_double(Spree::TaxProvider::Internal, refund: nil, void: nil, estimate: nil))
  end

  describe Spree::Returns::Refund do
    let(:return_record) do
      Spree::Returns::Create.call(
        order: order,
        items: [{ fulfillment_item: order.fulfillment_items.first, quantity: 1 }]
      ).value
    end

    before do
      Spree::Returns::Approve.call(return_record: return_record)
      Spree::Returns::Receive.call(return_record: return_record)
    end

    # The regression: `order.payments` is empty on a grouped child, so this
    # used to fail with :no_refundable_payments and a seller could not refund
    # a marketplace order at all.
    it 'refunds through the order group payment' do
      result = described_class.call(return_record: return_record, amount: 10)

      expect(result).to be_success
      refund = Spree::Refund.find_by(originator: return_record)
      expect(refund).to be_present
      expect(refund.payment).to eq(payment)
    end

    it 'attributes the refund to the child order being put right' do
      described_class.call(return_record: return_record, amount: 10)

      expect(Spree::Refund.find_by(originator: return_record).order).to eq(order)
    end

    it 'leaves the sibling share untouched' do
      expect {
        described_class.call(return_record: return_record, amount: 10)
      }.not_to change { Spree::Refund.where(order_id: sibling.id).count }.from(0)
    end

    # The share is the ceiling, not the payment: this order was captured 100 of
    # the payment's 200, so asking for more than 100 must not reach into the
    # sibling's half even though the payment itself could cover it.
    it 'refuses more than this order captured, however much the payment holds' do
      split.update!(captured_amount: 5)

      result = described_class.call(return_record: return_record, amount: 50)

      expect(result).to be_failure
      expect(Spree::Refund.where(order_id: order.id)).to be_empty
    end

    # A parcel reserves what it is about to draw before asking the gateway, so
    # a share can read captured while the charge is still in flight. Refunding
    # through it would hand back money nobody has taken.
    it 'skips a share whose capture is still in flight' do
      split.update!(claimed_amount: 100)

      result = described_class.call(return_record: return_record, amount: 10)

      expect(result).to be_failure
      expect(result.error.value).to eq(:no_refundable_payments)
    end
  end

  describe Spree::Claims::Resolve do
    let(:claim) do
      Spree::Claims::Create.call(
        order: order,
        items: [{ line_item: order.line_items.first, quantity: 1 }]
      ).value
    end

    before { Spree::Claims::Approve.call(claim: claim) }

    it 'refunds through the order group payment' do
      result = described_class.call(claim: claim, resolution: 'refund',
                                    refund_method: 'original_payment', amount: 10)

      expect(result).to be_success
      expect(Spree::Refund.find_by(originator: claim)&.payment).to eq(payment)
    end
  end

  describe Spree::Exchanges::Fulfill do
    let(:variant) { create(:variant) }
    let(:exchange) do
      Spree::Exchanges::Create.call(
        order: order,
        items: [{
          fulfillment_item: order.fulfillment_items.first,
          quantity: 1,
          new_variant: variant
        }]
      ).value
    end

    before do
      Spree::Exchanges::Approve.call(exchange: exchange)
      Spree::Exchanges::Receive.call(exchange: exchange)
    end

    # Only owes money when the replacement is cheaper than what came back.
    it 'refunds a price difference through the order group payment' do
      allow_any_instance_of(Spree::Exchange).to receive(:price_difference).and_return(-10)

      result = described_class.call(exchange: exchange, refund_method: 'original_payment')

      expect(result).to be_success
      expect(Spree::Refund.where(originator: exchange).map(&:payment).uniq).to eq([payment])
    end
  end

  # Cancelling a child order is the other way money goes back, and a seller
  # may cancel their own. The bound has to hold there too: the workflow reads
  # this order's shares, never the whole payment.
  describe Spree::Orders::Cancel do
    # A dispatched order cannot be withdrawn from, so these use orders that
    # have not gone out — which is the case a seller actually cancels.
    before do
      [order, sibling].each do |placed|
        placed.fulfillments.update_all(status: 'unfulfilled')
        placed.update_columns(fulfillment_status: 'unfulfilled')
        placed.reload
      end
    end

    it 'refunds only this order’s share of the group payment' do
      result = described_class.call(order: order, refund_payments: true)

      expect(result).to be_success

      refunds = Spree::Refund.where(order_id: order.id)
      expect(refunds.sum(&:amount)).to eq(100)
      # The sibling's captured share is untouched, and its own order has no
      # refund written against it.
      expect(Spree::Refund.where(order_id: sibling.id)).to be_empty
      expect(sibling_split.reload.captured_amount).to eq(100)
    end

    it 'releases the authorization without refunding when not asked' do
      result = described_class.call(order: order, refund_payments: false)

      expect(result).to be_success
      expect(Spree::Refund.where(order_id: order.id)).to be_empty
      # The share it reserved but never drew is given up.
      expect(split.reload.authorized_amount).to eq(split.captured_amount)
    end
  end
end
