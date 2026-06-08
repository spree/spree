require 'spec_helper'

RSpec.describe Spree::OrderRouting::Strategy::Base, type: :model do
  around do |example|
    registered = Spree.order_routing.strategies.dup
    example.run
    Spree.order_routing.strategies.replace(registered)
  end

  describe '.registered' do
    it 'returns the strategies registered by core' do
      expect(described_class.registered).to include(
        Spree::OrderRouting::Strategy::Rules,
        Spree::OrderRouting::Strategy::Legacy
      )
    end

    it 'does not register the internal Reducer collaborator' do
      expect(described_class.registered).not_to include(Spree::OrderRouting::Strategy::Reducer)
    end
  end

  describe '.registered?' do
    it 'matches a registered class by name string' do
      expect(described_class.registered?('Spree::OrderRouting::Strategy::Rules')).to be(true)
    end

    it 'is false for an unregistered class name' do
      expect(described_class.registered?('Spree::OrderRouting::Strategy::Reducer')).to be(false)
    end

    it 'reflects classes added to the registry' do
      stub_const('CustomStrategy', Class.new(described_class))
      Spree.order_routing.strategies << CustomStrategy

      expect(described_class.registered?('CustomStrategy')).to be(true)
    end
  end

  describe '.display_name' do
    it 'uses the i18n label when present' do
      expect(Spree::OrderRouting::Strategy::Rules.display_name).to eq('Rules (ordered)')
    end
  end
end
