require 'spec_helper'

RSpec.describe Spree::Returns::Eligibility do
  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store) }
  let(:unit) { order.fulfillment_items.first }

  subject(:eligibility) { described_class.new(order) }

  before do
    %w[
      Spree::Returns::EligibilityValidator
      Spree::Returns::DigitalContentValidator
      Spree::Returns::ReturnableValidator
    ].each { |validator| Spree.hooks.register('returns.create.validate', validator) }
  end

  it 'is eligible inside the return window' do
    expect(eligibility.to_h).to include(eligible: true, errors: [])
    expect(eligibility.to_h[:return_window_ends_at]).to eq((order.completed_at + 30.days).iso8601)
  end

  it 'offers the whole unit while nothing has come back' do
    expect(eligibility.for_unit(unit)).to eq(returnable_quantity: unit.quantity, non_returnable_reason: nil)
  end

  it 'writes nothing' do
    expect { eligibility.to_h && eligibility.for_unit(unit) }.not_to change(Spree::Return, :count)
  end

  context 'outside the return window' do
    before { order.update_columns(completed_at: 60.days.ago) }

    it 'says why, as the create call would' do
      expect(eligibility).not_to be_eligible
      expect(eligibility.errors.first[:code]).to eq('outside_return_window')
      expect(eligibility.errors.first[:message]).to include('30-day return window')
    end

    it 'offers no unit' do
      expect(eligibility.for_unit(unit)).to eq(returnable_quantity: 0, non_returnable_reason: 'outside_return_window')
    end
  end

  context 'when the order was canceled' do
    before { order.update_columns(status: 'canceled') }

    it 'is not eligible' do
      expect(eligibility.errors.first[:code]).to eq('order_canceled')
    end
  end

  it 'counts units already returned' do
    Spree::Returns::Create.call(order: order, items: [{ fulfillment_item: unit, quantity: unit.quantity }])

    expect(described_class.new(order.reload).for_unit(unit)).to eq(returnable_quantity: 0, non_returnable_reason: 'already_returned')
  end

  it 'names the rule a unit fails' do
    unit.line_item.update_columns(returnable: false)

    expect(eligibility.for_unit(unit)).to eq(returnable_quantity: 0, non_returnable_reason: 'not_returnable')
  end

  # A store's own handler reaches the storefront without further work.
  context 'with a custom handler' do
    let(:handler) do
      Class.new do
        def call(workflow)
          return if workflow.items.empty?

          workflow.errors.add(:base, :final_sale_category, message: 'Swimwear is final sale')
          workflow.reject!
        end
      end
    end

    before do
      stub_const('SwimwearPolicy', handler)
      Spree.hooks.register('returns.create.validate', 'SwimwearPolicy')
    end

    after { Spree.hooks.unregister('returns.create.validate', 'SwimwearPolicy') }

    it 'reports the custom verdict for a unit' do
      expect(eligibility.for_unit(unit)[:non_returnable_reason]).to eq('final_sale_category')
    end
  end

  # A store handler written for the real create call may not expect an empty
  # item list; the preview must never break the order read because of it.
  context 'when a store handler raises' do
    before do
      stub_const('BrittlePolicy', Class.new { def call(workflow) = workflow.items.first.fetch(:fulfillment_item) })
      Spree.hooks.register('returns.create.validate', 'BrittlePolicy')
    end

    after { Spree.hooks.unregister('returns.create.validate', 'BrittlePolicy') }

    it 'says nothing rather than failing' do
      expect(eligibility.to_h).to include(eligible: true, errors: [])
    end
  end
end
