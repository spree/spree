require 'spec_helper'
require 'rake'

describe 'spree:backfill_order_coupon_codes' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'order_coupon_code_backfill.rake')
  end

  let(:store) { @default_store }

  def run_task
    task = Rake::Task['spree:backfill_order_coupon_codes']
    task.reenable
    old = $stdout.dup
    $stdout.reopen(File::NULL, 'w')
    task.invoke
  ensure
    $stdout.reopen(old)
  end

  let(:order) { create(:completed_order_with_totals, store: store) }

  it 'backfills from an attached coupon code row' do
    promotion = create(:promotion, kind: :coupon_code, store: store)
    create(:coupon_code, promotion: promotion, order: order, code: 'MULTI42', state: 'used')
    order.update_columns(coupon_code: nil)

    run_task

    expect(order.reload.read_attribute(:coupon_code)).to eq('multi42')
  end

  it 'falls back to the applied single-code promotion' do
    promotion = create(:promotion, kind: :coupon_code, code: 'save5', store: store)
    Spree::OrderPromotion.create!(order: order, promotion: promotion)
    order.update_columns(coupon_code: nil)

    run_task

    expect(order.reload.read_attribute(:coupon_code)).to eq('save5')
  end

  it 'leaves orders without promotion records untouched and is idempotent' do
    order.update_columns(coupon_code: nil)

    run_task
    expect(order.reload.read_attribute(:coupon_code)).to be_nil

    order.update_columns(coupon_code: 'existing')
    run_task
    expect(order.reload.read_attribute(:coupon_code)).to eq('existing')
  end
end
