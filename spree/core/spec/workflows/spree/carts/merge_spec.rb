require 'spec_helper'

RSpec.describe Spree::Carts::Merge do
  let(:store) { @default_store }
  let(:variant) { create(:variant) }

  let(:cart) { create(:cart, store: store) }
  let(:other_cart) { create(:cart, store: store) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe 'merging' do
    it 'absorbs the quantity of a matching item and destroys the drained cart' do
      cart.line_items.create!(variant: variant, quantity: 1, currency: cart.currency)
      other_cart.line_items.create!(variant: variant, quantity: 2, currency: other_cart.currency)

      result = described_class.call(cart: cart, other_cart: other_cart)

      expect(result).to be_success
      expect(cart.reload.line_items.count).to eq(1)
      expect(cart.line_items.first.quantity).to eq(3)
      expect { other_cart.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'moves a non-matching item across' do
      other_variant = create(:variant)
      cart.line_items.create!(variant: variant, quantity: 1, currency: cart.currency)
      other_cart.line_items.create!(variant: other_variant, quantity: 1, currency: other_cart.currency)

      described_class.call(cart: cart, other_cart: other_cart)

      expect(cart.reload.line_items.map(&:variant)).to match_array([variant, other_variant])
    end

    it 'returns the cart untouched when there is nothing to merge' do
      expect(described_class.call(cart: cart, other_cart: nil)).to be_success
      expect(described_class.call(cart: cart, other_cart: cart)).to be_success
    end

    it 'keeps a currency-mismatched cart instead of destroying it' do
      allow(other_cart).to receive(:currency).and_return('EUR')

      result = described_class.call(cart: cart, other_cart: other_cart)

      expect(result).to be_failure
      expect(other_cart.reload).to be_persisted
    end
  end

  # Folding a paid cart in would destroy it with the payment session its
  # gateway webhook settles; folding items into one would change the total
  # its money was charged for.
  describe 'a cart a gateway has taken money for' do
    before do
      cart.line_items.create!(variant: variant, quantity: 1, currency: cart.currency)
      other_cart.line_items.create!(variant: variant, quantity: 2, currency: other_cart.currency)
    end

    %i[cart other_cart].each do |paid|
      it "refuses the merge when the #{paid} has a settled payment session" do
        create(:bogus_payment_session, cart: send(paid), amount: 10).update_column(:status, 'completed')

        result = described_class.call(cart: cart, other_cart: other_cart)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('completion_in_progress')
        expect(other_cart.reload.line_items.sum(:quantity)).to eq(2)
        expect(cart.reload.line_items.sum(:quantity)).to eq(1)
      end
    end

    # The first check reads the carts unlocked; a session settling on the
    # source cart after it (settle_payment! runs under the cart's lock) must
    # still stop the merge, or the merge destroys the cart and the payment.
    context 'when the source cart settles after the first check' do
      let!(:payment_session) { create(:bogus_payment_session, cart: other_cart, amount: 10) }
      let(:settled_payment) { Spree::Payment.find_by(response_code: payment_session.external_id) }

      before do
        # The pending session alone would refuse at the first check; this
        # example is about the settle the locked recheck has to see.
        allow(other_cart).to receive(:payment_session_open?).and_return(false)
        settled = false
        allow(other_cart).to receive(:completion_claimed?) do
          unless settled
            settled = true
            payment_session.update_column(:status, 'completed')
            create(:payment, cart: other_cart, order: nil, payment_method: payment_session.payment_method,
                             response_code: payment_session.external_id, amount: 10, status: 'pending')
          end
          false
        end
      end

      it 'refuses under the row locks and keeps the source cart and its payment' do
        result = described_class.call(cart: cart, other_cart: other_cart)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('completion_in_progress')
        expect(Spree::Cart.exists?(other_cart.id)).to be(true)
        expect(settled_payment).to be_present
        expect(settled_payment.cart_id).to eq(other_cart.id)
        expect(Spree::LineItem.where(cart_id: other_cart.id).sum(:quantity)).to eq(2)
        expect(Spree::LineItem.where(cart_id: cart.id).sum(:quantity)).to eq(1)
      end
    end
  end

  # A gateway can capture a session while it is still pending here, before
  # its webhook lands. Folding that cart in would destroy the session, and
  # the webhook could no longer record the payment or place the order.
  describe 'a source cart with a payment session the gateway may still settle' do
    before do
      cart.line_items.create!(variant: variant, quantity: 1, currency: cart.currency)
      other_cart.line_items.create!(variant: variant, quantity: 2, currency: other_cart.currency)
    end

    %w[pending processing completed failed].each do |status|
      it "refuses the merge and keeps the source cart while its session is #{status}" do
        payment_session = create(:bogus_payment_session, cart: other_cart, amount: 10)
        payment_session.update_column(:status, status)

        result = described_class.call(cart: cart, other_cart: other_cart)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('completion_in_progress')
        expect(Spree::Cart.exists?(other_cart.id)).to be(true)
        expect(Spree::PaymentSession.exists?(payment_session.id)).to be(true)
        expect(Spree::LineItem.where(cart_id: other_cart.id).sum(:quantity)).to eq(2)
        expect(Spree::LineItem.where(cart_id: cart.id).sum(:quantity)).to eq(1)
      end
    end

    %w[canceled expired].each do |status|
      it "merges when the source cart's only session is #{status}" do
        create(:bogus_payment_session, cart: other_cart, amount: 10).update_column(:status, status)

        result = described_class.call(cart: cart, other_cart: other_cart)

        expect(result).to be_success
        expect(cart.reload.line_items.sum(:quantity)).to eq(3)
        expect(Spree::Cart.exists?(other_cart.id)).to be(false)
      end
    end

    it 'merges when the surviving cart has a pending session' do
      create(:bogus_payment_session, cart: cart, amount: 10)

      result = described_class.call(cart: cart, other_cart: other_cart)

      expect(result).to be_success
      expect(cart.reload.line_items.sum(:quantity)).to eq(3)
    end

  end

  # The merge takes the cart's lock first while the session is still
  # pending — the gateway has captured, its webhook has not landed. The
  # recheck under the lock must refuse, so the webhook can still settle.
  describe 'a source cart whose session is still pending at the locked check' do
    let(:other_cart) { create(:cart_ready_for_delivery, store: store) }
    let(:payment_method) { create(:bogus_payment_method, store: store) }
    let!(:payment_session) do
      create(:bogus_payment_session, cart: other_cart, payment_method: payment_method, amount: other_cart.total)
    end

    before do
      # As if the session opened after the unlocked first check.
      allow(other_cart).to receive(:payment_session_open?).and_return(false)
    end

    it 'refuses, and the webhook still records the payment and places the order' do
      quantity = Spree::LineItem.where(cart_id: other_cart.id).sum(:quantity)

      result = described_class.call(cart: cart, other_cart: other_cart)

      expect(result).to be_failure
      expect(result.error.value[:code]).to eq('completion_in_progress')
      expect(Spree::Cart.exists?(other_cart.id)).to be(true)
      expect(payment_session.reload).to be_pending
      expect(Spree::LineItem.where(cart_id: other_cart.id).sum(:quantity)).to eq(quantity)

      webhook = Spree::Payments::HandleWebhook.call(
        payment_method: payment_method, action: :captured, payment_session: payment_session
      )

      expect(webhook).to be_success
      placed = Spree::Cart.find(other_cart.id)
      expect(placed.completed_at).to be_present
      expect(placed.order.line_items.sum(:quantity)).to eq(quantity)
      expect(placed.order.payments.completed.count).to eq(1)
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto the merge before anything moves' do
      other_cart.line_items.create!(variant: variant, quantity: 2, currency: other_cart.currency)

      Spree.hooks.register('carts.merge.validate') { |flow| flow.reject!('merging is disabled') }

      result = described_class.call(cart: cart, other_cart: other_cart)

      expect(result).to be_failure
      expect(result.error.to_s).to eq('merging is disabled')
      expect(cart.reload.line_items).to be_empty
      expect(other_cart.reload.line_items.count).to eq(1)
    end

    it 'runs after_merge once the carts are folded together' do
      other_cart.line_items.create!(variant: variant, quantity: 1, currency: other_cart.currency)

      merged_count = nil
      Spree.hooks.register('carts.merge.after_merge') { |flow| merged_count = flow.cart.line_items.count }

      described_class.call(cart: cart, other_cart: other_cart)

      expect(merged_count).to eq(1)
    end

    # Extensions keep records against the guest cart's lines; the map tells
    # them where each line went while the folded-in lines still exist.
    describe 'after_items_moved' do
      let(:other_variant) { create(:variant) }
      let!(:existing) { cart.line_items.create!(variant: variant, quantity: 1, currency: cart.currency) }
      let!(:absorbed) { other_cart.line_items.create!(variant: variant, quantity: 2, currency: other_cart.currency) }
      let!(:moved) { other_cart.line_items.create!(variant: other_variant, quantity: 1, currency: other_cart.currency) }

      it 'maps each guest line to the line now holding it, before the absorbed ones are deleted' do
        seen = nil
        seen_cart_lines = nil
        Spree.hooks.register('carts.merge.after_items_moved') do |flow|
          seen = flow.line_item_map.to_h { |from, to| [from.id, [to.id, Spree::LineItem.exists?(from.id)]] }
          seen_cart_lines = flow.cart.line_items.to_a
        end

        described_class.call(cart: cart, other_cart: other_cart)

        expect(seen).to eq(absorbed.id => [existing.id, true], moved.id => [moved.id, true])
        expect(seen_cart_lines).to contain_exactly(existing, moved)
        expect(Spree::LineItem.exists?(absorbed.id)).to be(false)
        expect(cart.reload.line_items).to contain_exactly(existing, moved)
      end

      it 'rolls the merge back when a handler raises' do
        Spree.hooks.register('carts.merge.after_items_moved') { |_flow| raise ActiveRecord::RecordInvalid, Spree::Cart.new }

        expect { described_class.call(cart: cart, other_cart: other_cart) }.to raise_error(ActiveRecord::RecordInvalid)
        expect(other_cart.reload.line_items).to contain_exactly(absorbed, moved)
        expect(existing.reload.quantity).to eq(1)
      end
    end
  end
end
