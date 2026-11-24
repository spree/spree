require 'spec_helper'

RSpec.describe Spree::Refunds::Create do
  let(:payment) { create(:payment, status: 'completed', amount: 45.75) }

  before do
    Spree.hooks.clear!
    allow_any_instance_of(Spree::Refund).to receive(:perform!).and_return(true)
  end

  after { Spree.hooks.clear! }

  describe 'refunding' do
    it 'creates a refund for the full creditable balance and credits it at the gateway' do
      creditable = payment.credit_allowed
      expect_any_instance_of(Spree::Refund).to receive(:perform!)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(result.value).to be_a(Spree::Refund)
      expect(result.value.amount).to eq(creditable)
    end

    it 'refunds a partial amount' do
      result = described_class.call(payment: payment, amount: 10)

      expect(result.value.amount).to eq(10)
    end

    it 'leaves the exact residual after partial refunds, and refunds it to the cent' do
      described_class.call(payment: payment, amount: BigDecimal('10.33'))
      described_class.call(payment: payment.reload, amount: BigDecimal('0.29'))

      expect(payment.reload.credit_allowed).to eq(BigDecimal('35.13'))

      result = described_class.call(payment: payment, amount: BigDecimal('35.13'))

      expect(result).to be_success
      expect(payment.reload.credit_allowed).to eq(BigDecimal('0'))
    end

    it 'records the originator' do
      originator = create(:return)

      result = described_class.call(payment: payment, originator: originator)

      expect(result.value.originator).to eq(originator)
    end

    it 'refuses to refund a payment that was never captured' do
      pending_payment = create(:payment, status: 'pending')

      result = described_class.call(payment: pending_payment)

      expect(result).to be_failure
      expect(result.error.value).to eq(:payment_not_refundable)
      expect(pending_payment.refunds).to be_empty
    end

    it 'refuses an amount above the creditable balance' do
      result = described_class.call(payment: payment, amount: payment.amount + 10)

      expect(result).to be_failure
      expect(result.error.value).to eq(:refund_amount_exceeds_balance)
      expect(payment.refunds).to be_empty
    end

    it 'refuses a non-positive amount' do
      expect(described_class.call(payment: payment, amount: 0)).to be_failure
    end

    # Store credit given back for an order is recorded as a refund against the
    # payment, so the payment's own balance stops a card refund from giving
    # the same money back again (V-3832).
    context 'paid as store credit' do
      let(:credit) do
        create(:store_credit, refunded_order: payment.order, customer: payment.order.customer,
                              store: payment.order.store, amount: 20)
      end

      it 'records a completed refund linked to the credit without calling the gateway' do
        expect_any_instance_of(Spree::Refund).not_to receive(:perform!)
        expect(payment).to receive(:publish_event).with('payment.refunded', nil, hash_including(:refund_id))

        result = described_class.call(payment: payment, amount: 20, store_credit: credit)

        expect(result).to be_success
        expect(result.value).to have_attributes(status: 'completed', store_credit: credit,
                                                transaction_id: credit.prefixed_id, amount: 20)
        expect(result.value).to be_to_store_credit
        expect(credit.refunds).to eq([result.value])
      end

      it 'leaves the card only what the credit did not give back' do
        described_class.call(payment: payment, amount: 20, store_credit: credit)

        refused = described_class.call(payment: payment.reload, amount: payment.amount)
        expect(refused).to be_failure
        expect(refused.error.value).to eq(:refund_amount_exceeds_balance)

        expect(described_class.call(payment: payment).value.amount).to eq(BigDecimal('25.75'))
      end

      it 'moves the order payment total' do
        payment.order.update_columns(payment_total: payment.amount)

        described_class.call(payment: payment, amount: 20, store_credit: credit)

        expect(payment.order.reload.payment_total).to eq(BigDecimal('25.75'))
      end
    end

    it 'creates the refund row under the payment row lock' do
      expect(payment).to receive(:with_lock).and_call_original

      described_class.call(payment: payment)
    end

    it 'destroys the uncredited refund when the gateway declines' do
      allow_any_instance_of(Spree::Refund).to receive(:perform!).
        and_raise(Spree::Core::GatewayError, 'declined')

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq('declined')
      expect(payment.refunds.reload).to be_empty
    end

    it 'keeps a credited refund even when a later step fails' do
      allow_any_instance_of(Spree::Refund).to receive(:perform!) do |refund|
        refund.update_columns(transaction_id: 'txn_123')
      end
      Spree.hooks.register('refunds.create.after_refund') { |flow| flow.reject!('observer exploded') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(payment.refunds.reload.count).to eq(1)
      expect(payment.refunds.first.transaction_id).to eq('txn_123')
    end
  end

  describe 'crediting at the gateway' do
    before { allow_any_instance_of(Spree::Refund).to receive(:perform!).and_call_original }

    context 'when the provider answers at once' do
      it 'completes the refund and publishes payment.refunded' do
        expect(payment).to receive(:publish_event).with('payment.refunded', nil, refund_id: kind_of(String))

        refund = described_class.call(payment: payment, amount: 10).value

        expect(refund.reload).to be_completed
        expect(refund.read_attribute(:status)).to eq('completed')
        expect(refund.transaction_id).to be_present
      end
    end

    context 'when the provider answers later' do
      before { payment.payment_method.update!(preferred_requested_mode: true) }

      it 'leaves the refund requested with its transaction id and publishes refund.requested' do
        expect(payment).not_to receive(:publish_event).with('payment.refunded', any_args)
        expect_any_instance_of(Spree::Refund).to receive(:publish_event).with('refund.requested')

        result = described_class.call(payment: payment, amount: 10)

        expect(result).to be_success
        refund = result.value.reload
        expect(refund).to be_requested
        expect(refund.transaction_id).to start_with('BGS-refund-')
      end
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto the refund before the record is created' do
      Spree.hooks.register('refunds.create.validate') { |flow| flow.reject!('refunds disabled') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq('refunds disabled')
      expect(payment.refunds).to be_empty
    end

    it 'exposes the created refund to after_refund' do
      seen = nil
      Spree.hooks.register('refunds.create.after_refund') { |flow| seen = flow.refund }

      described_class.call(payment: payment, amount: 5)

      expect(seen).to be_a(Spree::Refund)
      expect(seen.amount).to eq(5)
    end
  end
  # A marketplace basket is taken with one charge against the order group, so
  # a child order holds no payment of its own — only its share. The
  # whole-payment balance says nothing about whose money it is, which is what
  # these cover.
  describe 'a payment shared by a split checkout' do
    let(:store) { @default_store }
    let(:group) { create(:order_group, store: store) }
    let!(:order) { grouped_order(1) }
    let!(:sibling) { grouped_order(2) }

    let!(:shared_payment) do
      create(:payment, order: nil, cart: nil, order_group: group, amount: 200, status: 'completed')
    end
    let!(:split) do
      create(:payment_split, payment: shared_payment, order: order,
                             authorized_amount: 100, captured_amount: 100)
    end
    let!(:sibling_split) do
      create(:payment_split, payment: shared_payment, order: sibling,
                             authorized_amount: 100, captured_amount: 100)
    end

    def grouped_order(suffix)
      create(:completed_order_with_totals, store: store).tap do |placed|
        placed.update_columns(order_group_id: group.id, number: "#{group.number}-#{suffix}")
        placed.reload
      end
    end

    it "refunds up to the named order's own share" do
      result = described_class.call(payment: shared_payment, order: order, amount: 100)

      expect(result).to be_success
      expect(result.value.amount).to eq(100)
    end

    it "refuses an amount above the named order's share, even though the payment covers it" do
      result = described_class.call(payment: shared_payment, order: order, amount: 150)

      expect(result).to be_failure
      expect(result.error.value).to eq(:refund_amount_exceeds_balance)
      expect(shared_payment.refunds).to be_empty
    end

    # The pre-flight check reads the share before the payment row is locked, so
    # a sibling refund landing in between would otherwise let both commit and
    # together overdraw this child. `Spree::Refund` cannot catch it: it
    # validates `credit_allowed`, which is the whole payment's balance.
    it 'refuses when another refund claimed the share after the pre-flight check' do
      allow(shared_payment).to receive(:with_lock).and_wrap_original do |original, &block|
        create(:refund, payment: shared_payment, order: order, amount: 100)
        original.call(&block)
      end

      result = described_class.call(payment: shared_payment, order: order, amount: 100)

      expect(result).to be_failure
      expect(result.error.value).to eq(:refund_amount_exceeds_balance)
      # Only the refund that got there first survives.
      expect(Spree::Refund.where(order_id: order.id).sum(:amount)).to eq(100)
    end
  end
end
