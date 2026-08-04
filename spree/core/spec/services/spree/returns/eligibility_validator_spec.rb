require 'spec_helper'

RSpec.describe Spree::Returns::EligibilityValidator do
  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store) }

  def open_return(created_by: nil)
    Spree::Returns::Create.call(
      order: order,
      items: [{ fulfillment_item: order.fulfillment_items.first, quantity: 1 }],
      created_by: created_by
    )
  end

  # The engine registers this at boot, but any spec calling Spree.hooks.clear!
  # earlier in the run wipes it for the rest of the process — so register it
  # here rather than depending on file order.
  before do
    Spree.hooks.register('returns.create.validate', described_class.name)
    Spree.hooks.register('exchanges.create.validate', described_class.name)
  end

  it 'is registered on the create workflows' do
    expect(Spree.hooks.for('returns.create.validate').map(&:class)).to include(described_class)
    expect(Spree.hooks.for('exchanges.create.validate').map(&:class)).to include(described_class)
  end

  context 'within the window' do
    it 'allows a customer return' do
      order.update_columns(completed_at: 5.days.ago)

      expect(open_return).to be_success
    end
  end

  context 'outside the window' do
    before { order.update_columns(completed_at: 60.days.ago) }

    it 'rejects a customer return' do
      result = open_return

      expect(result).to be_failure
      expect(result.error.value).to include('30-day return window')
      expect(order.reload.returns).to be_empty
    end

    # A supervisor making an exception is ordinary retail — and the override
    # is attributable, because created_by lands on the return.
    it 'lets staff open one anyway' do
      admin = create(:admin_user)

      result = open_return(created_by: admin)

      expect(result).to be_success
      expect(result.value.created_by).to eq(admin)
    end
  end

  describe 'the window comes from the market' do
    let(:market) { order.market || create(:market, store: store) }

    before { order.update_columns(market_id: market.id, completed_at: 20.days.ago) }

    it 'uses a shorter market window' do
      market.update!(preferred_return_window_days: 14)

      expect(open_return).to be_failure
    end

    it 'uses a longer market window' do
      market.update!(preferred_return_window_days: 90)

      expect(open_return).to be_success
    end

    # Nil is the escape hatch for a market with no time limit at all.
    it 'treats a nil window as unlimited' do
      market.update!(preferred_return_window_days: nil)
      order.update_columns(completed_at: 5.years.ago)

      expect(open_return).to be_success
    end
  end

  it 'ignores an order that was never completed' do
    # Returns::Create rejects it for its own reasons; the validator must not
    # blow up on a nil completed_at first.
    order.update_columns(completed_at: nil)

    expect { open_return }.not_to raise_error
  end
end
