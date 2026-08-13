require 'spec_helper'

# The module factory is a deprecated shell over Spree::HasNumber (removed in
# 6.1). What matters here is that models written against the old API still get
# numbered — not how the number is produced, which has its own spec.
describe Spree::Core::NumberGenerator do
  let(:model) do
    Class.new(ApplicationRecord) do
      def self.name = 'Spree::LegacyNumbered'

      self.table_name = 'spree_orders'

      include Spree::Core::NumberGenerator.new(prefix: 'R')
    end
  end

  before do
    allow(Spree::Deprecation).to receive(:warn)
    # The bare test class has no store association, so the concern falls back
    # to the current store for its numbering settings.
    Spree::Current.store = @default_store
  end

  after { Spree::Current.store = nil }

  it 'warns that the module is going away' do
    model

    expect(Spree::Deprecation).to have_received(:warn).with(/removed in Spree 6.1/)
  end

  it 'points at the replacement' do
    model

    expect(Spree::Deprecation).to have_received(:warn).with(/has_spree_number/)
  end

  it 'still numbers records on create' do
    record = model.new(currency: 'USD')
    record.validate

    expect(record.number).to start_with('R')
  end

  it 'leaves a caller-supplied number alone' do
    record = model.new(currency: 'USD', number: 'R-KEEP-ME')
    record.validate

    expect(record.number).to eq('R-KEEP-ME')
  end

  it 'exposes the prefix it was built with' do
    expect(described_class.new(prefix: 'R').prefix).to eq('R')
  end
end
