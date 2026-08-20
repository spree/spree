require 'spec_helper'


describe Spree::StoreCredits::Apply, type: :service do
  let(:store) { @default_store }

  describe '#call' do
    subject { described_class.call(order: order) }

    let(:order_total) { 500.00 }

    before do
      create(:store_credit_payment_method)
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
      let(:order) { create(:order, customer: store_credit.user, total: order_total, store: store) }

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
      let(:order) { create(:order, customer: store_credit.user, total: order_total, store: store) }
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
      let(:order) { create(:order, customer: store_credit.user, total: order_total, store: store) }

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

      it 'adjusts amount when order total changes' do
        order.update_column(:total, 300)

        described_class.call(order: order.reload)
        order.reload

        expect(order.payments.store_credits.checkout.count).to eq(1)
        expect(order.payments.store_credits.checkout.first.amount).to eq(300)
      end
    end

    context 'there are multiple store credits' do
      let(:amount_difference) { 100 }
      let!(:older_store_credit) { create(:store_credit, amount: (order_total - amount_difference), store: store, created_at: 2.days.ago) }
      let!(:newer_store_credit) do
        create(:store_credit, amount: order_total, customer: older_store_credit.user, store: store, created_at: 1.day.ago)
      end
      let(:order) { create(:order, customer: older_store_credit.user, total: order_total, store: store) }

      before do
        Timecop.scale(3600)
      end

      after { Timecop.return }

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
end
