require 'spec_helper'

RSpec.describe Spree::OrderRouting::Strategy::Base, type: :model do
  describe 'Spree.order_routing.strategies' do
    it 'includes the core strategies and excludes the internal Reducer collaborator' do
      expect(Spree.order_routing.strategies).to include(
        Spree::OrderRouting::Strategy::Rules,
        Spree::OrderRouting::Strategy::Legacy
      )
      expect(Spree.order_routing.strategies).not_to include(Spree::OrderRouting::Strategy::Reducer)
    end
  end

  describe '.display_name' do
    it 'uses the i18n label when present' do
      expect(Spree::OrderRouting::Strategy::Rules.display_name).to eq('Rules (ordered)')
    end
  end
end
