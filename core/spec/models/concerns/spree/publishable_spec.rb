# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Publishable, events: true do
  before do
    Spree::Events.reset!
  end

  after do
    Spree::Events.reset!
  end

  # Define a test serializer for the spec
  let(:test_serializer_class) do
    Class.new(Spree::Events::BaseSerializer) do
      protected

      def attributes
        {
          id: resource.id,
          name: resource.name,
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end

  let(:publishable_class) do
    Class.new(Spree::Base) do
      self.table_name = 'spree_products'

      include Spree::Publishable
    end
  end

  let(:instance) { publishable_class.new(id: 1, name: 'Test Product', updated_at: Time.current) }

  describe '#publish_event' do
    before do
      stub_const('Spree::TestProduct', publishable_class)
      stub_const('Spree::Events::TestProductSerializer', test_serializer_class)
    end

    it 'publishes an event with the model payload' do
      received_event = nil
      Spree::Events.subscribe('test_product.custom', async: false) { |e| received_event = e }
      Spree::Events.activate!

      instance.publish_event('test_product.custom')

      expect(received_event).to be_present
      expect(received_event.name).to eq('test_product.custom')
      expect(received_event.payload['id']).to eq(1)
      expect(received_event.payload['name']).to eq('Test Product')
    end

    it 'allows custom payload' do
      received_event = nil
      Spree::Events.subscribe('test_product.custom', async: false) { |e| received_event = e }
      Spree::Events.activate!

      instance.publish_event('test_product.custom', { custom: 'data' })

      expect(received_event.payload).to eq({ 'custom' => 'data' })
    end

    it 'does not publish when events are disabled' do
      received = false
      Spree::Events.subscribe('test_product.custom', async: false) { received = true }
      Spree::Events.activate!

      Spree::Events.disable do
        instance.publish_event('test_product.custom')
      end

      expect(received).to be false
    end
  end

  describe '#event_payload' do
    context 'with a serializer defined' do
      before do
        stub_const('Spree::TestProduct', publishable_class)
        stub_const('Spree::Events::TestProductSerializer', test_serializer_class)
      end

      it 'returns the serialized payload' do
        payload = instance.event_payload

        expect(payload[:id]).to eq(1)
        expect(payload[:name]).to eq('Test Product')
        expect(payload[:updated_at]).to be_present
      end
    end

    context 'without a serializer defined' do
      let(:no_serializer_class) do
        Class.new(Spree::Base) do
          self.table_name = 'spree_products'
          include Spree::Publishable
        end
      end

      before do
        stub_const('Spree::NoSerializer', no_serializer_class)
      end

      it 'raises MissingSerializerError with helpful message' do
        instance = no_serializer_class.new(id: 1, name: 'Test')

        expect { instance.event_payload }.to raise_error(
          Spree::Publishable::MissingSerializerError,
          /Missing event serializer for Spree::NoSerializer/
        )
      end

      it 'includes example code in the error message' do
        instance = no_serializer_class.new(id: 1, name: 'Test')

        expect { instance.event_payload }.to raise_error(
          Spree::Publishable::MissingSerializerError,
          /class Spree::Events::NoSerializerSerializer < Spree::Events::BaseSerializer/
        )
      end
    end

    context 'with anonymous class' do
      it 'returns nil for event_serializer_class' do
        anon_class = Class.new(Spree::Base) do
          self.table_name = 'spree_products'
          include Spree::Publishable
        end

        instance = anon_class.new(id: 1)
        expect(instance.event_serializer_class).to be_nil
      end
    end
  end

  describe '#event_prefix' do
    before do
      stub_const('Spree::Product', publishable_class)
      stub_const('Spree::Events::ProductSerializer', test_serializer_class)
    end

    it 'returns the model name element' do
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
      end
    end

    before do
      stub_const('Spree::TestProduct', lifecycle_class)
      stub_const('Spree::Events::TestProductSerializer', test_serializer_class)
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

    # Note: These specs use ApplicationRecord directly to test Publishable in isolation
    # since Spree::Base now has lifecycle events enabled by default
    context 'with only option' do
      let(:limited_class) do
        Class.new(ApplicationRecord) do
          self.table_name = 'spree_products'

          include Spree::Publishable
          publishes_lifecycle_events only: [:create]
        end
      end

      it 'only registers specified callbacks' do
        expect(limited_class._commit_callbacks.map(&:filter)).to include(:publish_create_event)
        expect(limited_class._commit_callbacks.map(&:filter)).not_to include(:publish_update_event)
        expect(limited_class._commit_callbacks.map(&:filter)).not_to include(:publish_destroy_event)
      end
    end

    context 'with except option' do
      let(:except_class) do
        Class.new(ApplicationRecord) do
          self.table_name = 'spree_products'

          include Spree::Publishable
          publishes_lifecycle_events except: [:update]
        end
      end

      it 'excludes specified callbacks' do
        expect(except_class._commit_callbacks.map(&:filter)).to include(:publish_create_event)
        expect(except_class._commit_callbacks.map(&:filter)).not_to include(:publish_update_event)
        expect(except_class._commit_callbacks.map(&:filter)).to include(:publish_delete_event)
      end
    end

    context 'with skip_lifecycle_events' do
      let(:skipped_class) do
        Class.new(Spree::Base) do
          self.table_name = 'spree_products'
          skip_lifecycle_events
        end
      end

      it 'disables event publishing for the model' do
        expect(skipped_class.publish_events).to be false
      end
    end
  end

  describe '.event_prefix' do
    before do
      stub_const('Spree::OrderLineItem', publishable_class)
      stub_const('Spree::Events::OrderLineItemSerializer', test_serializer_class)
    end

    it 'derives from model name' do
      expect(Spree::OrderLineItem.event_prefix).to eq('order_line_item')
    end

    it 'can be customized' do
      stub_const('Spree::CustomModel', publishable_class)
      stub_const('Spree::Events::CustomModelSerializer', test_serializer_class)
      Spree::CustomModel.event_prefix = 'custom'
      expect(Spree::CustomModel.event_prefix).to eq('custom')
    end
  end
end
