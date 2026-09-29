require 'spec_helper'

RSpec.describe Spree::Carts::ReapExpiredJob do
  let(:store) { @default_store }
  let(:other_store) { create(:store) }

  after { Spree::Config.store_scope_guard = nil }

  it 'reaps expired carts in the store that owns them' do
    Spree::Config.store_scope_guard = 'raise'
    carts = [store, other_store].map { |owner| create(:cart, store: owner, updated_at: 1.year.ago) }
    reaped = []
    allow_any_instance_of(Spree::Cart).to receive(:destroy).and_wrap_original do |original|
      reaped << [original.receiver, Spree::Current.store]
      original.call
    end

    described_class.perform_now

    expect(reaped).to contain_exactly([carts.first, store], [carts.last, other_store])
    expect(Spree::Cart.where(id: carts.map(&:id))).to be_empty
  end

  it 'keeps a cart that has not expired' do
    cart = create(:cart, store: store)

    described_class.perform_now

    expect(Spree::Cart.exists?(cart.id)).to be(true)
  end
end
