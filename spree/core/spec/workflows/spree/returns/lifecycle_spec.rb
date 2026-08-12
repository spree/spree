require 'spec_helper'

RSpec.describe 'Spree::Returns workflows' do
  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store, line_items_count: 2) }
  let(:fulfillment_items) { order.fulfillment_items.to_a }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  def create_return(items: nil, **overrides)
    Spree::Returns::Create.call(
      order: order,
      items: items || [{ fulfillment_item: fulfillment_items.first, quantity: 1 }],
      **overrides
    )
  end

  describe Spree::Returns::Create do
    it 'opens a requested return with line items' do
      result = create_return

      expect(result).to be_success
      expect(result.value).to be_requested
      expect(result.value.return_line_items.count).to eq(1)
    end

    it 'defaults the stock location to where the goods shipped from' do
      expect(create_return.value.stock_location).to eq(order.shipments.first.stock_location)
    end

    it 'refuses an order that was never completed' do
      cart_order = create(:order, store: store)

      result = Spree::Returns::Create.call(order: cart_order, items: [])

      expect(result).to be_failure
    end

    it 'refuses to return more than was fulfilled' do
      result = create_return(items: [{ fulfillment_item: fulfillment_items.first, quantity: 99 }])

      expect(result).to be_failure
      expect(result.error.value).to include('can be returned')
    end

    # Units already covered by an open return must not come back twice.
    it 'counts quantities already requested on another return' do
      create_return

      result = create_return

      expect(result).to be_failure
    end

    it 'lets a validate handler enforce a return window' do
      Spree.hooks.register('returns.create.validate') do |workflow|
        workflow.reject!('outside the return window') if workflow.order.completed_at < 30.days.ago
      end
      order.update_columns(completed_at: 60.days.ago)

      result = create_return

      expect(result).to be_failure
      expect(result.error.value).to eq('outside the return window')
      expect(order.reload.returns).to be_empty
    end
  end

  describe Spree::Returns::Approve do
    it 'moves a requested return to approved' do
      return_record = create_return.value

      result = Spree::Returns::Approve.call(return_record: return_record)

      expect(result).to be_success
      expect(result.value).to be_approved
      expect(result.value.approved_at).to be_present
    end

    it 'refuses anything not currently requested' do
      return_record = create(:approved_return, store: store)

      expect(Spree::Returns::Approve.call(return_record: return_record)).to be_failure
    end
  end

  describe Spree::Returns::Receive do
    let(:return_record) { create(:approved_return, store: store) }
    let(:line) { return_record.return_line_items.first }

    it 'receives everything as requested by default' do
      result = Spree::Returns::Receive.call(return_record: return_record)

      expect(result).to be_success
      expect(result.value).to be_received
      expect(line.reload.received_quantity).to eq(line.quantity)
    end

    it 'restocks resellable goods' do
      variant = line.variant
      stock_item = return_record.stock_location.stock_item_or_create(variant)

      expect { Spree::Returns::Receive.call(return_record: return_record) }.
        to change { stock_item.reload.count_on_hand }.by(line.quantity)
    end

    # The whole reason receiving is a workflow and not a state transition.
    it 'records a partial, non-resellable receipt without restocking' do
      variant = line.variant
      stock_item = return_record.stock_location.stock_item_or_create(variant)

      result = Spree::Returns::Receive.call(
        return_record: return_record,
        items: [{ return_line_item: line, quantity: 1, resellable: false }]
      )

      expect(result).to be_success
      expect(line.reload.received_quantity).to eq(1)
      expect(line.resellable).to be(false)
      expect(stock_item.reload.count_on_hand).to eq(stock_item.count_on_hand)
    end

    it 'refuses to receive more than was requested' do
      result = Spree::Returns::Receive.call(
        return_record: return_record,
        items: [{ return_line_item: line, quantity: line.quantity + 5 }]
      )

      expect(result).to be_failure
    end

    it 'refuses a return that has not been approved' do
      requested = create(:return, store: store)

      expect(Spree::Returns::Receive.call(return_record: requested)).to be_failure
    end
  end

  describe Spree::Returns::Refund do
    let(:return_record) { create(:received_return, store: store) }

    it 'refuses a return that has not been received' do
      approved = create(:approved_return, store: store)

      expect(Spree::Returns::Refund.call(return_record: approved)).to be_failure
    end

    it 'refuses an unknown refund method' do
      result = Spree::Returns::Refund.call(return_record: return_record, refund_method: 'crypto')

      expect(result).to be_failure
      expect(result.error.value[:base].join).to include('original_payment')
    end

    it 'refuses more than the return is owed' do
      result = Spree::Returns::Refund.call(return_record: return_record, amount: 10_000)

      expect(result).to be_failure
      expect(result.error.value).to eq(:refund_exceeds_balance)
    end

    context 'to store credit' do
      it 'issues credit inside the transaction and marks the return refunded' do
        result = Spree::Returns::Refund.call(return_record: return_record, refund_method: 'store_credit')

        expect(result).to be_success
        expect(result.value).to be_refunded
        credit = Spree::StoreCredit.find_by(originator: return_record)
        expect(credit).to be_present
        expect(credit.amount).to eq(return_record.refund_total)
      end

      it 'credits only the lines that actually arrived' do
        # Two of three announced units came back, so the third must not be
        # credited — the same rule resolve_amount applies to the money.
        line = return_record.return_line_items.first
        line.update!(quantity: 3, received_quantity: 2)
        # A second announced line the warehouse never received.
        unreceived = create(:return_line_item,
                            return: return_record,
                            fulfillment_item: line.fulfillment_item,
                            line_item: line.line_item,
                            variant: line.variant,
                            quantity: 1)

        order = return_record.order
        provider = instance_double(Spree::TaxProvider::Internal, refund: nil, estimate: nil)
        allow(order).to receive(:tax_provider).and_return(provider)
        allow_any_instance_of(Spree::Return).to receive(:order).and_return(order)

        Spree::Returns::Refund.call(return_record: return_record, refund_method: 'store_credit')

        expect(provider).to have_received(:refund) do |_order, lines, **|
          expect(lines).to include(line)
          expect(lines).not_to include(unreceived)
        end
      end

      it 'credits the returned items against the filed tax document' do
        order = return_record.order
        provider = instance_double(Spree::TaxProvider::Internal, refund: nil, estimate: nil)
        allow(order).to receive(:tax_provider).and_return(provider)
        allow_any_instance_of(Spree::Return).to receive(:order).and_return(order)

        Spree::Returns::Refund.call(return_record: return_record, refund_method: 'store_credit')

        expect(provider).to have_received(:refund).with(
          order, return_record.return_line_items.to_a,
          amount: return_record.refund_total, tax_date: order.completed_at
        )
      end

      # A partial refund must not hand the provider the returned lines with no
      # word of how little went back: crediting their full tax would reclaim tax
      # the merchant kept, and a return is marked refunded only once.
      it 'tells the provider how much was actually refunded' do
        order = return_record.order
        provider = instance_double(Spree::TaxProvider::Internal, refund: nil, estimate: nil)
        allow(order).to receive(:tax_provider).and_return(provider)
        allow_any_instance_of(Spree::Return).to receive(:order).and_return(order)

        part = (return_record.refund_total / 2).round(2)

        Spree::Returns::Refund.call(return_record: return_record, amount: part,
                                    refund_method: 'store_credit')

        expect(provider).to have_received(:refund).with(
          order, anything, amount: part, tax_date: order.completed_at
        )
      end

      it 'lets a validate handler veto before any credit is issued' do
        Spree.hooks.register('returns.refund.validate') { |flow| flow.reject!('refunds on hold') }

        result = Spree::Returns::Refund.call(return_record: return_record, refund_method: 'store_credit')

        expect(result).to be_failure
        expect(Spree::StoreCredit.where(originator: return_record)).to be_empty
        expect(return_record.reload).to be_received
      end
    end

    context 'to the original payment' do
      before { allow_any_instance_of(Spree::Refund).to receive(:perform!).and_return(true) }

      it 'creates a refund against the completed payment' do
        result = Spree::Returns::Refund.call(return_record: return_record)

        expect(result).to be_success
        expect(return_record.reload.refunds).to be_present
        expect(return_record.refunds.first.originator).to eq(return_record)
      end
    end
  end

  describe Spree::Returns::Cancel do
    it 'cancels a requested return' do
      return_record = create_return.value

      result = Spree::Returns::Cancel.call(return_record: return_record, reason: 'changed their mind')

      expect(result).to be_success
      expect(result.value).to be_canceled
      expect(result.value.memo).to include('changed their mind')
    end

    # Once the merchant holds the goods, the way out is a refund.
    it 'refuses a return that was already received' do
      received = create(:received_return, store: store)

      expect(Spree::Returns::Cancel.call(return_record: received)).to be_failure
    end

    it 'frees the quantity for a new return request' do
      create_return.value.then { |r| Spree::Returns::Cancel.call(return_record: r) }

      expect(create_return).to be_success
    end
  end
end
