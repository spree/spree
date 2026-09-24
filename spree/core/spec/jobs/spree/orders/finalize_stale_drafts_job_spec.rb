require 'spec_helper'

RSpec.describe Spree::Orders::FinalizeStaleDraftsJob do
  let(:store) { @default_store }
  let(:other_store) { create(:store) }
  let(:workflow) { Spree::Dependencies.carts_complete_workflow.constantize }

  def stale_draft(store)
    cart = create(:cart, store: store)
    create(:order, store: store, cart: cart, status: 'draft', created_at: 1.hour.ago)
  end

  after { Spree::Config.store_scope_guard = nil }

  it 'finalizes each stale draft in the store that owns it' do
    Spree::Config.store_scope_guard = 'raise'
    orders = [stale_draft(store), stale_draft(other_store)]
    finalized = []
    allow(workflow).to receive(:call) do |cart:|
      finalized << [cart, Spree::Current.store]
      double(failure?: false)
    end

    described_class.perform_now

    expect(finalized).to contain_exactly([orders.first.cart, store], [orders.last.cart, other_store])
  end

  it 'leaves a draft that is not stale yet' do
    stale_draft(store).update_columns(created_at: 1.minute.ago)
    allow(workflow).to receive(:call)

    described_class.perform_now

    expect(workflow).not_to have_received(:call)
  end
end
