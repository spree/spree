require 'spec_helper'


describe Spree::StoreCredits::Apply, type: :service do
  let(:store) { @default_store }

  describe '#call' do
    subject { described_class.call(order: order) }

    let(:order_total) { 500.00 }

    before do
      create(:store_credit_payment_method)
    end

    context 'when another store has the first available payment method' do
      let(:store) { create(:store) }
      let(:store_credit) { create(:store_credit, amount: order_total, store: store) }
      let(:order) { create(:order, customer: store_credit.customer, total: order_total, store: store) }
      let!(:payment_method) { create(:store_credit_payment_method, store: store, position: 100) }

      it 'uses the payment method belonging to the order store' do
        expect(subject).to be_success
        expect(order.reload.payments.store_credits.first.payment_method).to eq(payment_method)
      end

      it 'does not require an available payment method when nothing is outstanding' do
        payment_method.update!(active: false)
        order.update_columns(total: 10, item_total: 10, payment_total: 10)

        expect(subject).not_to be_success
        expect(order.reload.payments).to be_empty
      end

      it 'does not fall back to a foreign method when the store has none available' do
        payment_method.update!(active: false)

        expect { subject }.to raise_error('Store credit payment method could not be found')
        expect(order.reload.payments).to be_empty
      end
    end

    context 'there is no store credit' do
      let(:order) { create(:store_credits_order_without_user, total: order_total) }

      before do
        # callbacks recalculate total based on line items
        # this ensures the total is what we expect
        order.update_column(:total, order_total)
        subject
        order.reload
      end

      it 'does not create a store credit payment' do
        expect(order.payments.count).to eq 0
      end

      it 'returns error' do
        expect(subject.success?).to eq(false)
        expect(subject.error.to_s).to eq('User does not have any Store Credits available')
      end
    end

    context 'there is enough store credit to pay for the entire order' do
      subject { described_class.call(order: order, amount: requested_amount) }

      let(:store_credit) { create(:store_credit, amount: order_total, store: store) }
      let(:order) { create(:order, customer: store_credit.customer, total: order_total, store: store) }

      context 'with no amount specified' do
        let(:requested_amount) { nil }

        it 'creates a store credit payment for the full amount' do
          expect(subject).to be_success

          expect(order.reload.payments.count).to eq 1
          expect(order.payments.first).to be_store_credit
          expect(order.payments.first.amount).to eq order_total
        end
      end

      context 'with store credit amount specified' do
        let(:requested_amount) { 300.0 }

        it 'creates a store credit payment for the specified amount' do
          expect(subject).to be_success

          expect(order.reload.payments.count).to eq 1
          expect(order.payments.first).to be_store_credit
          expect(order.payments.first.amount).to eq requested_amount
        end
      end
    end

    context 'the available store credit is not enough to pay for the entire order' do
      let(:expected_cc_total) { 100.0 }
      let(:store_credit_total) { order_total - expected_cc_total }
      let(:store_credit) { create(:store_credit, amount: store_credit_total, store: store) }
      let(:order) { create(:order, customer: store_credit.customer, total: order_total, store: store) }
      let!(:store_credit_2) { create(:store_credit, amount: 10) }

      before do
        # callbacks recalculate total based on line items
        # this ensures the total is what we expect
        order.update_column(:total, order_total)
      end

      it 'creates a store credit payment for the available amount' do
        expect(subject).to be_success

        expect(order.reload.payments.count).to eq 1
        expect(order.payments.first).to be_store_credit
        expect(order.payments.first.amount).to eq store_credit_total
      end
    end

    context 'when called again with an existing checkout store credit payment' do
      let(:store_credit) { create(:store_credit, amount: 500, store: store) }
      let(:order) { create(:order, customer: store_credit.customer, total: order_total, store: store) }

      before do
        order.update_column(:total, order_total)
        # First call creates the payment
        described_class.call(order: order)
        order.reload
      end

      it 'updates the existing payment in place instead of creating a new one' do
        expect(order.payments.store_credits.checkout.count).to eq(1)
        original_payment_id = order.payments.store_credits.checkout.first.id

        # Second call should update, not recreate
        described_class.call(order: order.reload)
        order.reload

        expect(order.payments.store_credits.checkout.count).to eq(1)
        expect(order.payments.store_credits.checkout.first.id).to eq(original_payment_id)
      end

      it 'does not create invalid payment records' do
        described_class.call(order: order.reload)
        order.reload

        expect(order.payments.where(status: 'invalid').count).to eq(0)
      end

      it 'records no new eligibility event when the amount has not changed' do
        eligible_events = store_credit.store_credit_events.where(action: Spree::StoreCredit::ELIGIBLE_ACTION)

        expect { described_class.call(order: order.reload) }.not_to(change { eligible_events.count })
      end

      it 'adjusts amount when order total changes' do
        order.update_column(:total, 300)

        described_class.call(order: order.reload)
        order.reload

        expect(order.payments.store_credits.checkout.count).to eq(1)
        expect(order.payments.store_credits.checkout.first.amount).to eq(300)
      end

      # Regression: completion takes a store credit payment against the event
      # recorded for its amount, so a payment resized after creation could no
      # longer be taken ("Could not find store credit").
      it 'can still take the payment after its amount changes' do
        order.update_column(:total, 300)

        described_class.call(order: order.reload)
        payment = order.reload.payments.store_credits.checkout.first
        Spree.payment_process_workflow.call(payment: payment, action: :purchase)

        expect(payment.reload).to be_completed
        expect(store_credit.reload.amount_used).to eq(300)
      end
    end

    # Regression: a payment not yet taken reserves nothing from its credit, but
    # the resize counted it twice, so re-applying a credit smaller than the new
    # total claimed more than it held and completion then failed.
    context 'when re-applied after the total grows past the credit' do
      let(:store_credit) { create(:store_credit, amount: 30, store: store) }
      let(:order) { create(:order, customer: store_credit.customer, total: 40, store: store) }

      before do
        order.update_column(:total, 40)
        described_class.call(order: order)
        order.update_column(:total, 45)
      end

      it 'never takes more than the credit holds' do
        described_class.call(order: order.reload)

        payments = order.reload.payments.store_credits.checkout
        expect(payments.count).to eq(1)
        expect(payments.sum(:amount)).to eq(30)
      end

      it 'draws the rest from another credit rather than the same one twice' do
        create(:store_credit, customer: store_credit.customer, amount: 100, store: store)

        described_class.call(order: order.reload)

        by_credit = order.reload.payments.store_credits.checkout.to_a.group_by(&:source_id).transform_values { |payments| payments.sum(&:amount) }
        expect(by_credit[store_credit.id]).to eq(30)
        expect(by_credit.values.sum).to eq(45)
      end
    end

    context 'when a gift card is applied to the order' do
      let(:store_credit) { create(:store_credit, amount: 500, store: store) }
      let(:order) do
        create(:order, customer: store_credit.customer, total: order_total, store: store,
                       gift_card: create(:gift_card, store: store))
      end

      before { order.update_column(:total, order_total) }

      it 'refuses, since a gift card and store credit are not combined on one order' do
        expect(subject).not_to be_success
        expect(subject.error.to_s).to eq("You can't apply store credit after you applied a gift card.")
        expect(order.reload.payments.store_credits).to be_empty
      end
    end

    context 'there are multiple store credits' do
      let(:amount_difference) { 100 }
      let!(:older_store_credit) { create(:store_credit, amount: (order_total - amount_difference), store: store, created_at: 2.days.ago) }
      let!(:newer_store_credit) do
        create(:store_credit, amount: order_total, customer: older_store_credit.customer, store: store, created_at: 1.day.ago)
      end
      let(:order) { create(:order, customer: older_store_credit.customer, total: order_total, store: store) }

      it 'spends the oldest store credit first' do
        expect(subject).to be_success

        older_payment = order.reload.payments.first
        newer_payment = order.payments.last

        expect(order.payments.size).to eq 2
        expect(older_payment.source).to eq older_store_credit
        expect(newer_payment.source).to eq newer_store_credit
        expect(older_payment.amount).to eq(order_total - amount_difference)
        expect(newer_payment.amount).to eq(amount_difference)
      end
    end
  end

  # Regression: outstanding_balance is zero or negative on a paid or overpaid
  # order, and this service runs on every recalculation. The loop used to
  # break only on exactly zero, so a negative balance wrote a store credit
  # payment for a negative amount.
  context 'when the order is already overpaid' do
    let(:overpaid_customer) { create(:customer) }
    let(:overpaid_order) { create(:order_with_line_items, store: store, customer: overpaid_customer) }

    before do
      create(:store_credit_payment_method)
      create(:store_credit, customer: overpaid_customer, amount: 50, store: store)
      overpaid_order.update_columns(total: 10, item_total: 10, payment_total: 40)
    end

    it 'writes no store credit payment' do
      described_class.call(order: overpaid_order)

      expect(overpaid_order.reload.payments.store_credits).to be_empty
    end
  end

  # Regression: credits were drawn oldest-first with no currency filter, so an
  # older credit in another currency was picked ahead of a usable one. Being
  # unusable it overshot the order's allowed amount and raised, aborting the
  # whole apply transaction.
  context 'when an older credit is in another currency' do
    let(:mixed_customer) { create(:customer) }
    let(:mixed_order) { create(:order_with_line_items, store: store, customer: mixed_customer) }

    # Derived, never hard-coded: the order's currency comes from its store, so
    # naming a fixed code here risks the "foreign" credit matching the order
    # and the example passing without exercising the filter at all.
    let(:foreign_currency) { mixed_order.currency == 'EUR' ? 'USD' : 'EUR' }

    before do
      create(:store_credit_payment_method)
      mixed_order.update_columns(total: 100, item_total: 100, payment_total: 0)
      create(:store_credit, customer: mixed_customer, amount: 50, store: store,
                            currency: foreign_currency, created_at: 2.days.ago)
      create(:store_credit, customer: mixed_customer, amount: 30, store: store,
                            currency: mixed_order.currency, created_at: 1.day.ago)
    end

    it 'draws only against the credit in the order currency' do
      expect(foreign_currency).not_to eq(mixed_order.currency)

      described_class.call(order: mixed_order)

      payments = mixed_order.reload.payments.store_credits
      expect(payments.count).to eq(1)
      expect(payments.first.source.currency).to eq(mixed_order.currency)
      expect(payments.first.amount).to eq(30)
    end
  end

  # Regression: applying a gift card issues the customer a store credit that
  # backs the card's payment on that one order. Drawing store credit for another
  # order spent that balance a second time, leaving the gift card's own order
  # unable to complete.
  context 'when the customer holds a store credit issued by a gift card' do
    let(:gift_card_customer) { create(:customer) }
    let(:gift_card_order) { create(:order_with_line_items, store: store, customer: gift_card_customer) }

    before do
      create(:store_credit_payment_method)
      gift_card_order.update_columns(total: 100, item_total: 100, payment_total: 0)
      create(:store_credit, customer: gift_card_customer, amount: 80, store: store,
                            originator: create(:gift_card, amount: 100, store: store), created_at: 2.days.ago)
    end

    it "draws only against the customer's own store credit" do
      create(:store_credit, customer: gift_card_customer, amount: 30, store: store, created_at: 1.day.ago)

      described_class.call(order: gift_card_order)

      payments = gift_card_order.reload.payments.store_credits
      expect(payments.count).to eq(1)
      expect(payments.first.source.originator).to be_nil
      expect(payments.first.amount).to eq(30)
    end

    it 'refuses when the customer has no store credit of their own' do
      result = described_class.call(order: gift_card_order)

      expect(result).not_to be_success
      expect(result.error.to_s).to eq('User does not have any Store Credits available')
      expect(gift_card_order.reload.payments.store_credits).to be_empty
    end
  end

  # V-3807: a store credit payment on a draft order puts its amount on hold at
  # once, so a second order cannot spend the same credit.
  context 'on a draft order' do
    let(:customer) { create(:customer) }
    let!(:credit) { create(:store_credit, customer: customer, amount: 10, store: store, created_at: 2.days.ago) }

    def draft_with_total(total)
      create(:order_with_line_items, store: store, customer: customer).tap do |draft|
        draft.update_columns(status: 'draft', completed_at: nil, total: total, payment_total: 0)
      end
    end

    before { create(:store_credit_payment_method, store: store) }

    it 'holds the applied amount on the credit' do
      described_class.call(order: draft_with_total(BigDecimal('44.99')))

      expect(credit.reload.amount_authorized).to eq(10)
      expect(credit.amount_remaining).to eq(0)
    end

    it 'draws a second order on a free credit, not on the held one' do
      described_class.call(order: draft_with_total(BigDecimal('44.99')))
      free_credit = create(:store_credit, customer: customer, amount: 30, store: store, created_at: 1.day.ago)
      second = draft_with_total(BigDecimal('20'))

      described_class.call(order: second, amount: 5)

      expect(second.reload.payments.store_credits.valid.map(&:source)).to eq([free_credit])
      expect(free_credit.reload.amount_authorized).to eq(5)
      expect(credit.reload.amount_authorized).to eq(10)
    end

    it 'draws on what a partly held credit has left' do
      described_class.call(order: draft_with_total(BigDecimal('4')))
      newer_credit = create(:store_credit, customer: customer, amount: 3, store: store, created_at: 1.day.ago)
      second = draft_with_total(BigDecimal('20'))

      expect(described_class.call(order: second)).to be_success

      by_credit = second.reload.payments.store_credits.valid.to_h { |payment| [payment.source, payment.amount] }
      expect(by_credit).to eq(credit => 6, newer_credit => 3)
    end

    it 'holds each credit a payment is drawn on' do
      credit.update!(amount: 6)
      other_credit = create(:store_credit, customer: customer, amount: 8, store: store, created_at: 1.day.ago)

      described_class.call(order: draft_with_total(BigDecimal('11.80')))

      expect(credit.reload.amount_authorized).to eq(6)
      expect(other_credit.reload.amount_authorized).to eq(BigDecimal('5.80'))
    end

    it 'moves the hold when the payment is resized' do
      draft = draft_with_total(BigDecimal('8'))
      described_class.call(order: draft)
      draft.update_column(:total, BigDecimal('6'))

      described_class.call(order: draft.reload)

      expect(draft.reload.payments.store_credits.valid.sum(:amount)).to eq(6)
      expect(credit.reload.amount_authorized).to eq(6)
    end

    it 'releases the hold when the store credit is removed' do
      draft = draft_with_total(BigDecimal('44.99'))
      described_class.call(order: draft)

      Spree::StoreCredits::Remove.call(order: draft.reload)

      expect(credit.reload.amount_authorized).to eq(0)
    end

    it 'releases the hold when the draft is deleted' do
      draft = draft_with_total(BigDecimal('44.99'))
      described_class.call(order: draft)

      draft.reload.destroy!

      expect(credit.reload.amount_authorized).to eq(0)
    end

    it 'does not hold credit applied to a cart' do
      cart = create(:cart_with_line_items, customer: customer, store: store)

      described_class.call(order: cart)

      expect(cart.reload.payments.store_credits.valid).to be_present
      expect(credit.reload.amount_authorized).to eq(0)
    end
  end
end
