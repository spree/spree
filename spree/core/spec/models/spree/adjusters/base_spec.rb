require 'spec_helper'

describe Spree::Adjusters::Base, type: :model do
  it 'defaults type to :fee' do
    expect(Class.new(described_class).type).to eq(:fee)
  end

  describe '.adjust_all' do
    it 'runs the adjuster once per adjustable' do
      adjuster_class = Class.new(described_class) do
        def update
          order.touched_adjustables << adjustable
        end
      end

      order = double(:order, touched_adjustables: [])
      adjustables = [double(:line_item), double(:shipment)]

      adjuster_class.adjust_all(order, adjustables)

      expect(order.touched_adjustables).to eq(adjustables)
    end
  end

  it 'requires subclasses to implement #update' do
    expect do
      described_class.new(double(:order), double(:adjustable)).update
    end.to raise_error(NotImplementedError)
  end
end
