# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Publishable do
  before do
    Spree::Events.reset!
  end

  after do
    Spree::Events.reset!
  end

  let(:publishable_class) do
    Class.new(Spree::Base) do
      self.table_name = 'spree_products'

      include Spree::Publishable

      # Simulate ActiveModel::Serialization
      def serializable_hash(options = {})
        { 'id' => id, 'name' => name }.merge(options[:extra] || {})
      end
    end
  end

  let(:instance) { publishable_class.new(id: 1, name: 'Test Product') }

  describe '#publish_event' do
    it 'publishes an event with the model payload' do
      received_event = nil
      Spree::Events.subscribe('product.custom', async: false) { |e| received_event = e }
      Spree::Events.activate!

      instance.publish_event('product.custom')

      expect(received_event).to be_present
      expect(received_event.name).to eq('product.custom')
      expect(received_event.payload['id']).to eq(1)
      expect(received_event.payload['name']).to eq('Test Product')
    end

    it 'allows custom payload' do
      received_event = nil
      Spree::Events.subscribe('product.custom', async: false) { |e| received_event = e }
      Spree::Events.activate!

      instance.publish_event('product.custom', { custom: 'data' })

      expect(received_event.payload).to eq({ 'custom' => 'data' })
    end

    it 'includes model metadata with IDs as strings' do
      received_event = nil
      Spree::Events.subscribe('product.custom', async: false) { |e| received_event = e }
      Spree::Events.activate!

      instance.publish_event('product.custom')

      expect(received_event.metadata['model_id']).to eq('1')
    end

    it 'does not publish when events are disabled' do
      received = false
      Spree::Events.subscribe('product.custom', async: false) { received = true }
      Spree::Events.activate!

      Spree::Events.disable do
        instance.publish_event('product.custom')
      end

      expect(received).to be false
    end
  end

  describe '#event_payload' do
    it 'returns serializable_hash by default' do
      expect(instance.event_payload).to eq({ 'id' => 1, 'name' => 'Test Product' })
    end

    context 'with custom serialization options' do
      let(:custom_class) do
        Class.new(Spree::Base) do
          self.table_name = 'spree_products'

          include Spree::Publishable
          self.event_serialization_options = { extra: { 'custom' => 'field' } }

          def serializable_hash(options = {})
            { 'id' => id }.merge(options[:extra] || {})
          end
        end
      end

      it 'uses the custom serialization options' do
        instance = custom_class.new(id: 1)
        expect(instance.event_payload).to eq({ 'id' => 1, 'custom' => 'field' })
      end
    end
  end

  describe '#event_prefix' do
    it 'returns the model name element' do
      stub_const('Spree::Product', publishable_class)
      instance = Spree::Product.new

      expect(instance.event_prefix).to eq('product')
    end
  end

  describe '.publishes_lifecycle_events' do
    let(:lifecycle_class) do
      Class.new(Spree::Base) do
        self.table_name = 'spree_products'

        include Spree::Publishable
        publishes_lifecycle_events

        def serializable_hash(_options = {})
          { 'id' => id, 'name' => name }
        end
      end
    end

    before do
      stub_const('Spree::TestProduct', lifecycle_class)
    end

    it 'enables lifecycle events' do
      expect(lifecycle_class.lifecycle_events_enabled).to be true
    end

    it 'publishes create event after commit', skip: 'Requires database transaction' do
      received_event = nil
      Spree::Events.subscribe('test_product.create', async: false) { |e| received_event = e }
      Spree::Events.activate!

      product = lifecycle_class.create!(name: 'New Product')

      expect(received_event).to be_present
      expect(received_event.name).to eq('test_product.create')
    end

    context 'with only option' do
      let(:limited_class) do
        Class.new(Spree::Base) do
          self.table_name = 'spree_products'

          include Spree::Publishable
          publishes_lifecycle_events only: [:create]
        end
      end

      it 'only registers specified callbacks' do
        # Verify that only create callback is registered
        expect(limited_class._commit_callbacks.map(&:filter)).to include(:publish_create_event)
        expect(limited_class._commit_callbacks.map(&:filter)).not_to include(:publish_update_event)
        expect(limited_class._commit_callbacks.map(&:filter)).not_to include(:publish_destroy_event)
      end
    end

    context 'with except option' do
      let(:except_class) do
        Class.new(Spree::Base) do
          self.table_name = 'spree_products'

          include Spree::Publishable
          publishes_lifecycle_events except: [:update]
        end
      end

      it 'excludes specified callbacks' do
        expect(except_class._commit_callbacks.map(&:filter)).to include(:publish_create_event)
        expect(except_class._commit_callbacks.map(&:filter)).not_to include(:publish_update_event)
        expect(except_class._commit_callbacks.map(&:filter)).to include(:publish_destroy_event)
      end
    end

    context 'with serialize option' do
      let(:serialize_class) do
        Class.new(Spree::Base) do
          self.table_name = 'spree_products'

          include Spree::Publishable
          publishes_lifecycle_events serialize: { only: [:id] }

          def serializable_hash(options = {})
            options[:only] ? { 'id' => id } : { 'id' => id, 'name' => name }
          end
        end
      end

      it 'uses custom serialization options' do
        expect(serialize_class.event_serialization_options).to eq({ only: [:id] })
      end
    end
  end

  describe '.event_prefix' do
    it 'derives from model name' do
      stub_const('Spree::OrderLineItem', publishable_class)
      expect(Spree::OrderLineItem.event_prefix).to eq('order_line_item')
    end

    it 'can be customized' do
      stub_const('Spree::CustomModel', publishable_class)
      Spree::CustomModel.event_prefix = 'custom'
      expect(Spree::CustomModel.event_prefix).to eq('custom')
    end
  end
end
