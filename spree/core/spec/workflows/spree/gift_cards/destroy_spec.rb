require 'spec_helper'

RSpec.describe Spree::GiftCards::Destroy do
  subject(:result) { described_class.call(gift_card: gift_card) }

  let(:store) { Spree::Store.default }
  let(:gift_card) { create(:gift_card, amount: 60, store: store) }

  def apply_to(record, total:)
    record.update_columns(total: total, currency: 'USD')
    expect(Spree.gift_card_apply_workflow.call(gift_card: gift_card, order: record)).to be_success
    gift_card.reload
  end

  def store_credits_from_card
    Spree::StoreCredit.where(originator_type: 'Spree::GiftCard', originator_id: gift_card.id)
  end

  it 'deletes an unused card' do
    expect(result).to be_success
    expect(Spree::GiftCard.exists?(gift_card.id)).to be(false)
  end

  # V-3836: a $30 card on a $20 draft order.
  context 'when a draft order holds the card' do
    let(:gift_card) { create(:gift_card, amount: 30, store: store) }
    let(:draft) { create(:order_with_totals, store: store, customer: create(:user), line_items_price: 20) }

    before { apply_to(draft, total: 20) }

    it 'takes the card off the draft and deletes it' do
      expect(result).to be_success

      draft.reload
      expect(draft.gift_card_id).to be_nil
      expect(draft.payments.store_credits.checkout).to be_empty
      expect(store_credits_from_card).to be_empty
      expect(Spree::GiftCard.exists?(gift_card.id)).to be(false)
    end

    it 'reports the released hold' do
      workflow = described_class.new
      workflow.call(gift_card: gift_card)

      expect(workflow.released_holds.map(&:id)).to eq([draft.id])
    end
  end

  # Holds never expire, so refusing here would strand the card for good.
  context 'when an abandoned guest cart holds the card' do
    let(:cart) { create(:cart_with_line_items, store: store, line_items_price: 60) }

    before { apply_to(cart, total: 60) }

    it 'releases the cart and deletes the card' do
      expect(result).to be_success
      expect(cart.reload.gift_card_id).to be_nil
      expect(cart.payments.store_credits.checkout).to be_empty
      expect(Spree::GiftCard.exists?(gift_card.id)).to be(false)
    end
  end

  context 'when a checkout is completing with the card' do
    let(:cart) { create(:cart_with_line_items, store: store, line_items_price: 30) }
    let(:abandoned_cart) { create(:cart_with_line_items, store: store, line_items_price: 30) }

    # Applying to one cart releases every other hold, so the claimed cart is
    # given the card directly.
    before do
      apply_to(abandoned_cart, total: 30)
      cart.update_columns(gift_card_id: gift_card.id, completing_at: Time.current)
    end

    it 'refuses and rolls back every hold it had released' do
      expect(result).to be_failure
      expect(result.error.value).to eq(:gift_card_held_by_another_order)

      expect(Spree::GiftCard.exists?(gift_card.id)).to be(true)
      expect(cart.reload.gift_card_id).to eq(gift_card.id)
      expect(abandoned_cart.reload.gift_card_id).to eq(gift_card.id)
      expect(abandoned_cart.payments.store_credits.checkout.sum(:amount)).to eq(30)
    end
  end

  context 'when the card has been redeemed' do
    let(:gift_card) { create(:gift_card, :redeemed, store: store) }

    it 'refuses with the model error' do
      expect(result).to be_failure
      expect(result.error.to_s).to eq("Can't delete a used gift card")
      expect(Spree::GiftCard.exists?(gift_card.id)).to be(true)
    end
  end

  it 'locks the card for the check and the delete' do
    expect(gift_card).to receive(:lock!).and_call_original
    expect(result).to be_success
  end
end
