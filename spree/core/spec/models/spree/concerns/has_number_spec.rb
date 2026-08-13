require 'spec_helper'

RSpec.describe Spree::HasNumber do
  after { Spree.number_generators.clear }

  describe 'assigning a number' do
    it 'numbers a record on create' do
      order = create(:order)

      expect(order.number).to be_present
    end

    it 'keeps a number supplied by the caller' do
      order = create(:order, number: 'R-CUSTOM-1')

      expect(order.number).to eq('R-CUSTOM-1')
    end

    it 'does not renumber on update' do
      order = create(:order)

      expect { order.update!(email: 'someone@example.com') }.not_to change(order, :number)
    end
  end

  describe 'prefixes' do
    it 'uses the model prefix for non-order documents' do
      expect(create(:stock_transfer).number).to start_with('T')
    end

    it 'uses the store prefix for orders' do
      stub_store_preferences(order_number_prefix: 'INV')

      expect(create(:order).number).to start_with('INV')
    end

    it 'appends the store suffix for orders' do
      stub_store_preferences(order_number_suffix: '-EU')

      expect(create(:order).number).to end_with('-EU')
    end
  end

  describe 'collisions' do
    it 'skips a candidate that is already taken' do
      taken = create(:order).number
      generator = instance_double(Spree::NumberGenerators::Sequential)
      allow(Spree::NumberGenerators::Sequential).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate).and_return(taken, 'R-FREE-1')

      expect(create(:order).number).to eq('R-FREE-1')
    end

    it 'gives up rather than looping forever' do
      taken = create(:order).number
      generator = instance_double(Spree::NumberGenerators::Sequential)
      allow(Spree::NumberGenerators::Sequential).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate) { taken }

      expect { create(:order) }.to raise_error(Spree::HasNumber::GenerationError)
    end
  end

  describe 'the registry' do
    let(:custom_generator) do
      Class.new(Spree::NumberGenerators::Base) do
        def generate(record)
          "CUSTOM-#{record.class.number_prefix}-1"
        end
      end
    end

    before { stub_const('MyApp::TestNumbers', custom_generator) }

    it 'uses a registered generator for that resource' do
      Spree.number_generators[:order] = 'MyApp::TestNumbers'

      expect(create(:order).number).to eq('CUSTOM-R-1')
    end

    it 'leaves other resources on the store default' do
      Spree.number_generators[:order] = 'MyApp::TestNumbers'

      expect(create(:stock_transfer).number).not_to start_with('CUSTOM')
    end

    it 'falls back to the store format once the entry is removed' do
      Spree.number_generators[:order] = 'MyApp::TestNumbers'
      Spree.number_generators.delete(:order)

      expect(create(:order).number).not_to start_with('CUSTOM')
    end
  end

  describe 'availability on every model' do
    it 'exposes the macro without a per-model include' do
      expect(Spree::Product).to respond_to(:has_spree_number)
    end

    it 'leaves models that never call it alone' do
      expect(Spree::Product.has_spree_number?).to be(false)
    end

    it 'reports models that opted in' do
      expect(Spree::Order.has_spree_number?).to be(true)
    end

    it 'adds no numbering callback to models that never call it' do
      callbacks = Spree::Product._validation_callbacks.map(&:filter)

      expect(callbacks).not_to include(:generate_number)
    end
  end

  describe 'when no store can be resolved' do
    it 'names the missing store rather than blaming collisions' do
      order = build(:order)
      allow(order).to receive(:number_store).and_return(nil)

      expect { order.generate_number }.
        to raise_error(Spree::HasNumber::GenerationError, /no store to read numbering settings from/)
    end
  end

  describe 'the store format preference' do
    it 'generates sequential numbers by default' do
      first = create(:order).number
      second = create(:order).number

      expect(second.sub(/\AR/, '').to_i).to eq(first.sub(/\AR/, '').to_i + 1)
    end

    it 'generates random numbers when the store opts in' do
      stub_store_preferences(document_number_format: 'random')

      expect(create(:order).number).to match(/\AR\d{9}\z/)
    end
  end
end
