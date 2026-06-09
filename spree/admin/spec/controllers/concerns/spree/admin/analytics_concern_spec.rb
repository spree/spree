require 'spec_helper'

RSpec.describe Spree::Admin::AnalyticsConcern do
  let(:controller_class) do
    Class.new(ActionController::Base) do
      include Spree::Admin::AnalyticsConcern
    end
  end

  let(:controller) { controller_class.new }

  describe '#calc_growth_rate' do
    it 'returns percent change from the previous period' do
      expect(controller.send(:calc_growth_rate, 150, 100)).to eq(50.0)
    end

    it 'returns negative percent when current is below previous' do
      expect(controller.send(:calc_growth_rate, 80, 100)).to eq(-20.0)
    end

    it 'returns zero when both periods are zero' do
      expect(controller.send(:calc_growth_rate, 0, 0)).to eq(0.0)
    end

    it 'returns nil when previous is zero and current is positive (no baseline)' do
      expect(controller.send(:calc_growth_rate, 50, 0)).to be_nil
    end

    it 'returns -100 when current is zero and previous is positive' do
      expect(controller.send(:calc_growth_rate, 0, 50)).to eq(-100.0)
    end

    it 'handles BigDecimal inputs' do
      expect(controller.send(:calc_growth_rate, BigDecimal('110'), BigDecimal('100'))).to be_within(0.0001).of(10.0)
    end
  end
end
