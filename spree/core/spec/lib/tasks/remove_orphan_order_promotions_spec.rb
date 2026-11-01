require 'spec_helper'
require 'rake'

describe 'spree:remove_orphan_order_promotions' do
  subject { Rake::Task['spree:remove_orphan_order_promotions'] }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'remove_orphan_order_promotions.rake')
  end

  before { subject.reenable }

  let(:store) { @default_store }
  let(:promotion) do
    create(:promotion_with_order_adjustment, code: 'save10', weighted_order_adjustment_amount: 10, store: store)
  end
  let(:cart) { create(:cart_with_line_items, line_items_count: 1, store: store) }

  before do
    cart.coupon_code = promotion.code
    Spree::PromotionHandler::Coupon.new(cart).apply
  end

  it 'removes order promotions whose promotion is gone and keeps the others' do
    kept_cart = create(:cart_with_line_items, line_items_count: 1, store: store)
    other = create(:promotion_with_order_adjustment, code: 'other5', weighted_order_adjustment_amount: 5, store: store)
    kept_cart.coupon_code = other.code
    Spree::PromotionHandler::Coupon.new(kept_cart).apply
    Spree::Promotion.unscoped.where(id: promotion.id).delete_all

    expect { silence_output { subject.invoke } }.to change(Spree::OrderPromotion, :count).by(-1)

    expect(cart.reload.order_promotions).to be_empty
    expect(kept_cart.reload.order_promotions.count).to eq(1)
  end

  def silence_output
    original = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original
  end
end
