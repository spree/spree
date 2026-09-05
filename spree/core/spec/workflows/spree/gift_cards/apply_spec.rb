require 'spec_helper'

RSpec.describe Spree::GiftCards::Apply do
  subject { described_class.call(gift_card: gift_card, order: order) }

  let(:store) { Spree::Store.default }
  let(:order) { create(:order, store: store, customer: order_user) }
  let(:order_user) { create(:user) }

  let(:gift_card) { create(:gift_card, amount: 50, store: store, customer: gift_card_user) }
  let(:gift_card_user) { nil }
  let(:store_credit_payment) { order.payments.store_credits.last }
  let(:store_credit) { store_credit_payment.source }

  before do
    order.update_column(:total, 30)
    order.update_column(:shipment_total, 10)
  end

  it 'applies the gift card to an order' do
    expect { subject }.to change(Spree::StoreCredit, :count).by(1)
    expect(subject).to be_success

    expect(order.reload.gift_card).to eq(gift_card)
    expect(order.gift_card_total).to eq(30)

    expect(gift_card.reload.amount_remaining).to eq(20)

    expect(store_credit_payment).to be_present
    expect(store_credit_payment).to be_checkout
    expect(store_credit_payment.source).to eq(gift_card.store_credits.last)
    expect(store_credit_payment.amount).to eq(30)

    expect(store_credit.amount).to eq(30)
    expect(store_credit.store).to eq(Spree::Store.default)
    expect(store_credit.originator).to eq(gift_card)
  end

  it 'calls recalculate_totals!' do
    expect(order).to receive(:recalculate_totals!)
    subject
  end

  context 'when the order has applied store credit' do
    let!(:store_credit_payment_method) { create(:store_credit_payment_method) }
    let!(:store_credit) { create(:store_credit, customer: order.user, amount: 10, store: store) }

    before do
      order.add_store_credit_payments
    end

    it 'responds with an error' do
      expect { subject }.not_to change(Spree::StoreCredit, :count)

      expect(subject).to be_failure
      expect(subject.error.value).to eq(:gift_card_using_store_credit_error)

      expect(order.reload.gift_card).to be_nil
      expect(order.total_applied_store_credit).to eq(10)
      expect(order.payments.store_credits.last.source.originator).to be_nil
    end
  end

  context 'when the gift card has a different currency' do
    let(:gift_card) { create(:gift_card, amount: 50, store: store, customer: gift_card_user, currency: 'USD') }
    let(:order) { create(:order, store: store, customer: order_user, currency: 'EUR') }

    it 'responds with an error' do
      expect(subject).to be_failure
      expect(subject.error.value).to eq(:gift_card_mismatched_currency)
    end
  end

  context 'when the gift card is assigned to a user' do
    let(:gift_card_user) { create(:user) }
    let(:order_user) { nil }

    context 'with valid user' do
      let(:order_user) { gift_card_user }

      it 'applies the gift card to the order' do
        expect(subject).to be_success
      end

      it 'calls recalculate_totals!' do
        expect(order).to receive(:recalculate_totals!)
        subject
      end
    end

    context 'with guest order' do
      it 'responds with an error' do
        expect(subject).to be_failure
        expect(subject.error.value).to eq(:gift_card_customer_not_logged_in)
      end
    end

    context 'with another user order' do
      let(:order_user) { create(:user) }

      it 'responds with an error' do
        expect(subject).to be_failure
        expect(subject.error.value).to eq(:gift_card_mismatched_customer)
      end
    end
  end

  context 'when applied concurrently to multiple orders' do
    let(:gift_card) { create(:gift_card, amount: 100, store: store) }
    let(:users) { Array.new(5) { create(:user) } }
    let(:orders) do
      users.map do |user|
        order = create(:order, store: store, customer: user)
        order.update_columns(total: 80, item_total: 80)
        order
      end
    end

    it 'does not generate store credits exceeding the gift card value' do
      threads = orders.map do |order|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            described_class.call(gift_card: gift_card, order: order)
          end
        end
      end
      threads.each(&:join)

      gift_card.reload
      total_credits = Spree::StoreCredit.where(originator: gift_card).sum(:amount)

      expect(total_credits).to be <= gift_card.amount
      expect(gift_card.amount_used).to be <= gift_card.amount
    end
  end

  # The store controllers check these at the edge, but the workflow is the
  # shared entry point, so it refuses a card that cannot be spent.
  context 'when the gift card cannot be spent' do
    it 'refuses an expired card' do
      gift_card.update!(expires_at: 1.day.ago)

      expect(subject).not_to be_success
      expect(subject.error.value).to eq(:gift_card_expired)
    end

    it 'refuses a canceled card' do
      gift_card.update!(status: 'canceled')

      expect(subject).not_to be_success
      expect(subject.error.value).to eq(:gift_card_canceled)
    end

    it 'refuses a redeemed card' do
      gift_card.update!(status: 'redeemed')

      expect(subject).not_to be_success
      expect(subject.error.value).to eq(:gift_card_already_redeemed)
    end
  end

  context 'when the gift card has no amount remaining' do
    before { gift_card.update!(amount_used: gift_card.amount) }

    it 'responds with an error' do
      expect { subject }.not_to change(Spree::StoreCredit, :count)

      expect(subject).to be_failure
      expect(subject.error.value).to eq(:gift_card_no_amount_remaining)

      expect(order.reload.gift_card).to be_nil
    end
  end

  context 'when the gift card is already held by another open cart' do
    let(:other_cart) { create(:cart, store: store, customer: order_user) }

    before do
      other_cart.update_column(:total, 50)
      expect(Spree.gift_card_apply_workflow.call(gift_card: gift_card, order: other_cart)).to be_success
    end

    it 'releases the other hold and applies the freed balance here' do
      expect(gift_card.reload.amount_remaining).to eq(0)

      expect(subject).to be_success

      expect(other_cart.reload.gift_card).to be_nil
      expect(other_cart.payments.store_credits.checkout).to be_empty

      expect(order.reload.gift_card).to eq(gift_card)
      expect(order.gift_card_total).to eq(30)
      expect(gift_card.reload.amount_remaining).to eq(20)
    end

    it 'reports the released holds' do
      workflow = described_class.new
      expect(workflow.call(gift_card: gift_card, order: order)).to be_success
      expect(workflow.released_holds.map(&:id)).to eq([other_cart.id])
    end

    context 'when the other hold cannot be released' do
      before do
        allow(Spree).to receive(:gift_card_remove_workflow).and_return(failing_remove_workflow)
      end

      let(:failing_remove_workflow) do
        double(call: Spree::ServiceModule::Result.new(false, nil, Spree::ServiceModule::ResultError.new('nope')))
      end

      it 'reports the discrepancy and refuses the apply' do
        expect(Rails.error).to receive(:report).with(
          an_instance_of(Spree::Core::GiftCardHoldReleaseFailed),
          hash_including(handled: true)
        )

        expect(subject).to be_failure
        expect(subject.error.value).to eq(:gift_card_held_by_another_order)

        expect(other_cart.reload.gift_card).to eq(gift_card)
        expect(order.reload.gift_card).to be_nil
      end
    end
  end

  context 'lock ordering' do
    let(:other_cart) { create(:cart, store: store, customer: order_user) }

    before do
      other_cart.update_column(:total, 50)
      expect(Spree.gift_card_apply_workflow.call(gift_card: gift_card, order: other_cart)).to be_success
    end

    # Spree::GiftCards::Remove locks its record and then the card. Holding the
    # card while reaching for another record would invert that and deadlock
    # against a concurrent remove of the same card.
    it 'releases holds before locking the gift card' do
      locked = []

      allow_any_instance_of(Spree::GiftCard).to receive(:lock!) do |card|
        locked << :gift_card
        card
      end
      allow(Spree.gift_card_remove_workflow).to receive(:call).and_wrap_original do |original, **kwargs|
        locked << :hold_released
        original.call(**kwargs)
      end

      expect(subject).to be_success
      expect(locked.first).to eq(:hold_released)
    end
  end

  context 'when the other cart is mid-completion' do
    let(:other_cart) { create(:cart, store: store, customer: order_user) }

    before do
      other_cart.update_column(:total, 50)
      expect(Spree.gift_card_apply_workflow.call(gift_card: gift_card, order: other_cart)).to be_success
      other_cart.update_column(:completing_at, Time.current)
    end

    it 'leaves the claimed hold alone and says the card is in use' do
      expect(subject).to be_failure
      expect(subject.error.value).to eq(:gift_card_held_by_another_order)

      expect(other_cart.reload.gift_card).to eq(gift_card)
      expect(order.reload.gift_card).to be_nil
    end

    context 'when the completion claim has gone stale' do
      before { other_cart.update_column(:completing_at, 1.day.ago) }

      it 'releases the abandoned hold' do
        expect(subject).to be_success

        expect(other_cart.reload.gift_card).to be_nil
        expect(order.reload.gift_card).to eq(gift_card)
      end
    end
  end

  context 'when a draft order from an in-flight checkout holds the card' do
    let(:completing_cart) { create(:cart, store: store, customer: order_user) }
    let!(:draft_order) do
      create(:order, store: store, customer: order_user, cart: completing_cart, status: 'draft').tap do |draft|
        draft.update_column(:total, 50)
        expect(Spree.gift_card_apply_workflow.call(gift_card: gift_card, order: draft)).to be_success
      end
    end

    before { completing_cart.update_column(:completing_at, Time.current) }

    it 'leaves the draft alone while its cart is being completed' do
      expect(subject).to be_failure
      expect(subject.error.value).to eq(:gift_card_held_by_another_order)

      expect(draft_order.reload.gift_card).to eq(gift_card)
      expect(draft_order.payments.checkout.store_credits).to be_present
      expect(order.reload.gift_card).to be_nil
    end

    it 'releases the draft once the completion claim goes stale' do
      completing_cart.update_column(:completing_at, 1.day.ago)

      expect(subject).to be_success

      expect(draft_order.reload.gift_card).to be_nil
      expect(order.reload.gift_card).to eq(gift_card)
    end
  end

  context 'when the gift card is held by a completed order' do
    let!(:completed_order) do
      create(:order, store: store, customer: order_user).tap do |other|
        other.update_column(:total, 50)
        expect(Spree.gift_card_apply_workflow.call(gift_card: gift_card, order: other)).to be_success
        other.update_column(:completed_at, Time.current)
      end
    end

    it 'leaves the settled hold alone' do
      expect(subject).to be_failure
      expect(subject.error.value).to eq(:gift_card_no_amount_remaining)

      expect(completed_order.reload.gift_card).to eq(gift_card)
    end
  end

  context 'when the order belongs to a non-default store' do
    let(:other_store) { create(:store, default: false) }
    let(:order) { create(:order, store: other_store, customer: order_user) }
    let(:gift_card) { create(:gift_card, amount: 50, store: other_store, customer: gift_card_user) }

    it 'applies the gift card to the order' do
      expect { subject }.to change(Spree::StoreCredit, :count).by(1)
      expect(subject).to be_success

      expect(order.reload.gift_card).to eq(gift_card)
      expect(order.gift_card_total).to eq(30)

      expect(gift_card.reload.amount_remaining).to eq(20)

      expect(store_credit_payment).to be_present
      expect(store_credit_payment).to be_checkout
      expect(store_credit_payment.source).to eq(gift_card.store_credits.last)
      expect(store_credit_payment.amount).to eq(30)

      expect(store_credit.amount).to eq(30)
      expect(store_credit.store).to eq(other_store)
      expect(store_credit.originator).to eq(gift_card)
    end

    it 'links the auto-created StoreCredit payment method only to the order store' do
      expect(subject).to be_success

      payment_method = order.payments.store_credits.last.payment_method
      expect(payment_method.store).to eq(other_store)
      expect(payment_method.available_for_store?(other_store)).to be true
    end

    context 'when a StoreCredit payment method already exists for the order store' do
      let!(:existing_payment_method) { create(:store_credit_payment_method, store: other_store) }

      it 'reuses the existing payment method without creating a duplicate' do
        expect { subject }.not_to change(Spree::PaymentMethod::StoreCredit, :count)
        expect(subject).to be_success
        expect(order.payments.store_credits.last.payment_method).to eq(existing_payment_method)
      end
    end
  end
end
