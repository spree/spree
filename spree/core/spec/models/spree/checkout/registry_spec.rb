require 'spec_helper'

RSpec.describe Spree::Checkout::Registry do
  after { described_class.reset! }

  describe '.register_step' do
    it 'adds a step' do
      described_class.register_step(
        name: :custom_step,
        satisfied: ->(_order) { false },
        requirements: ->(_order) { [{ step: 'custom_step', field: 'custom_field', message: 'Required' }] }
      )

      expect(described_class.steps.size).to eq(1)
      expect(described_class.steps.first.name).to eq('custom_step')
    end
  end

  describe '.add_requirement' do
    it 'adds a requirement' do
      described_class.add_requirement(
        step: :payment,
        field: :po_number,
        message: 'PO number is required',
        satisfied: ->(_order) { false }
      )

      expect(described_class.requirements.size).to eq(1)
      expect(described_class.requirements.first.field).to eq('po_number')
    end
  end

  describe '.remove_step' do
    it 'removes a step by name' do
      described_class.register_step(
        name: :custom_step,
        satisfied: ->(_order) { false },
        requirements: ->(_order) { [] }
      )

      expect { described_class.remove_step(:custom_step) }.to change { described_class.steps.size }.from(1).to(0)
    end
  end

  describe '.remove_requirement' do
    it 'removes a requirement by step and field' do
      described_class.add_requirement(
        step: :payment,
        field: :po_number,
        message: 'PO number is required',
        satisfied: ->(_order) { false }
      )

      expect { described_class.remove_requirement(step: :payment, field: :po_number) }
        .to change { described_class.requirements.size }.from(1).to(0)
    end
  end

  describe '.ordered_steps' do
    let(:noop) { ->(_) { false } }
    let(:empty_reqs) { ->(_) { [] } }

    it 'places step with before: constraint ahead of that step' do
      described_class.register_step(name: :loyalty, satisfied: noop, requirements: empty_reqs, before: :payment)
      described_class.register_step(name: :custom, satisfied: noop, requirements: empty_reqs, before: :delivery)

      names = described_class.ordered_steps.map(&:name)
      expect(names.index('custom')).to be < names.index('loyalty')
    end

    it 'places step with after: constraint following that step' do
      described_class.register_step(name: :verification, satisfied: noop, requirements: empty_reqs, after: :address)
      described_class.register_step(name: :review, satisfied: noop, requirements: empty_reqs, after: :payment)

      names = described_class.ordered_steps.map(&:name)
      expect(names.index('verification')).to be < names.index('review')
    end

    it 'appends steps without constraints at the end' do
      described_class.register_step(name: :positioned, satisfied: noop, requirements: empty_reqs, before: :delivery)
      described_class.register_step(name: :unpositioned, satisfied: noop, requirements: empty_reqs)

      names = described_class.ordered_steps.map(&:name)
      expect(names.last).to eq('unpositioned')
    end
  end

  describe '.reset!' do
    it 'clears all steps and requirements' do
      described_class.register_step(
        name: :custom_step,
        satisfied: ->(_order) { false },
        requirements: ->(_order) { [] }
      )
      described_class.add_requirement(
        step: :payment,
        field: :po_number,
        message: 'Required',
        satisfied: ->(_order) { false }
      )

      described_class.reset!

      expect(described_class.steps).to be_empty
      expect(described_class.requirements).to be_empty
    end
  end
end
