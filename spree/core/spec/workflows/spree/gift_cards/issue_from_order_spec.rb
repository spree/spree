require 'spec_helper'

RSpec.describe Spree::GiftCards::IssueFromOrder do
  subject { described_class.call(order: order, paid: true) }

  let(:store) { Spree::Store.default }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:product) { create(:gift_card_product, store: store) }
  let!(:line_item) { create(:line_item, order: order, product: product, quantity: 2, price: 50) }

  before { order.update_columns(payment_status: 'paid') }

  it 'issues one card per unit, worth the denomination' do
    expect { subject }.to change(Spree::GiftCard, :count).by(2)

    expect(subject).to be_success
    cards = line_item.gift_cards.reload
    expect(cards.map(&:amount)).to all(eq(50))
    expect(cards.map(&:currency)).to all(eq(order.currency))
    expect(cards.map(&:customer)).to all(be_nil)
    expect(cards.map(&:expires_at)).to all(be_nil)
    expect(subject.value).to match_array(cards)
  end

  it 'issues nothing the second time' do
    described_class.call(order: order, paid: true)

    expect { subject }.not_to change(Spree::GiftCard, :count)
    expect(subject.value).to eq([])
  end

  it 'tops a line up to its quantity' do
    create(:gift_card, line_item: line_item, store: store, amount: 50)

    expect { subject }.to change(Spree::GiftCard, :count).by(1)
  end

  it 'leaves the other lines alone' do
    expect(order.line_items.count).to be > 1
    subject

    expect(Spree::GiftCard.where(line_item_id: order.line_items.where.not(id: line_item.id))).to be_empty
  end

  it 'announces each card', events: true do
    published = []
    allow(Spree::Events).to receive(:publish).and_wrap_original do |method, name, *args, **kwargs|
      published << name
      method.call(name, *args, **kwargs)
    end

    subject

    expect(published.count('gift_card.issued')).to eq(2)
  end

  context 'when the store sets a validity' do
    before { allow(store).to receive(:preferred_gift_card_default_validity_days).and_return(365) }

    it 'expires the cards after it' do
      allow(order).to receive(:store).and_return(store)

      subject

      expect(line_item.gift_cards.reload.map(&:expires_at)).to all(eq(Time.zone.today + 365))
    end
  end

  context 'when nothing says the order is paid' do
    subject { described_class.call(order: order) }

    before { order.update_columns(payment_status: 'balance_due') }

    it 'issues nothing while money is still owed' do
      expect { subject }.not_to change(Spree::GiftCard, :count)
    end

    it 'does not take an order.paid on trust once the money has gone back' do
      expect { described_class.call(order: order, paid: true) }.not_to change(Spree::GiftCard, :count)
    end

    it 'issues once completed payments cover the total' do
      create(:payment, order: order, amount: order.reload.total, status: 'completed')

      expect { subject }.to change(Spree::GiftCard, :count).by(2)
    end
  end

  it 'issues nothing for a line staff gave away at no charge' do
    line_item.update_columns(price: 0)

    expect { subject }.not_to change(Spree::GiftCard, :count)
  end

  it 'counts validity from the day a scheduled card is sent' do
    allow_any_instance_of(Spree::Store).to receive(:preferred_gift_card_default_validity_days).and_return(30)
    line_item.assign_gift_card_recipient(email: 'friend@example.com', send_at: 60.days.from_now)

    subject

    expect(line_item.gift_cards.reload.map(&:expires_at)).to all(eq(Time.zone.today + 90))
  end

  it 'keeps a line from shrinking below the cards it issued' do
    subject

    expect(line_item.reload.update(quantity: 1)).to be(false)
    expect(line_item.errors.details[:quantity]).to include(a_hash_including(error: :below_issued_gift_cards))
  end

  it 'keeps a line that issued cards from being removed' do
    subject

    expect(line_item.reload.destroy).to be(false)
    expect(line_item.errors).to be_present
  end

  context 'when the order was canceled' do
    before { order.update_column(:status, 'canceled') }

    it 'issues nothing' do
      expect { subject }.not_to change(Spree::GiftCard, :count)
    end
  end
end
