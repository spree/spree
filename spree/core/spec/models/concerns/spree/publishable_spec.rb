# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Publishable, events: true do
  before do
    Spree::Events.reset!
  end

  after do
    Spree::Events.reset!
  end

  let(:v3_serializer_class) do
    Class.new do
      def initialize(resource, params: {})
        @resource = resource
        @params = params
      end

      def to_h
        { 'id' => 'test_prefix_1', 'name' => @resource.name }
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
      stub_const('Spree::Api::V3::TestProductSerializer', v3_serializer_class)
    end

    it 'publishes an event with the model payload' do
      received_event = nil
      Spree::Events.subscribe('test_product.custom', async: false) { |e| received_event = e }
      Spree::Events.activate!

      instance.publish_event('test_product.custom')

      expect(received_event).to be_present
      expect(received_event.name).to eq('test_product.custom')
      expect(received_event.payload['id']).to eq('test_prefix_1')
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
    context 'when a V3 serializer exists' do
      before do
        stub_const('Spree::TestProduct', publishable_class)
        stub_const('Spree::Api::V3::TestProductSerializer', v3_serializer_class)
      end

      it 'uses the V3 serializer' do
        payload = instance.event_payload

        expect(payload).to eq({ 'id' => 'test_prefix_1', 'name' => 'Test Product' })
      end
    end

    context 'when no serializer exists' do
      before do
        stub_const('Spree::NoSerializer', publishable_class)
      end

      it 'returns minimal fallback payload with id, created_at, updated_at' do
        now = Time.current
        instance = publishable_class.new(id: 1, name: 'Test', created_at: now, updated_at: now)

        payload = instance.event_payload

        expect(payload[:id]).to be_a(String)
        expect(payload[:id]).to be_present
        expect(payload[:created_at]).to eq(now.iso8601)
        expect(payload[:updated_at]).to eq(now.iso8601)
        expect(payload).not_to have_key(:name)
      end
    end
  end

  describe '#event_serializer_class' do
    context 'when V3 serializer exists by convention' do
      before do
        stub_const('Spree::TestProduct', publishable_class)
        stub_const('Spree::Api::V3::TestProductSerializer', v3_serializer_class)
      end

      it 'returns the serializer class' do
        expect(instance.event_serializer_class).to eq(v3_serializer_class)
      end
    end

    context 'when no V3 serializer exists' do
      before do
        stub_const('Spree::NoSerializer', publishable_class)
      end

      it 'returns nil' do
        expect(instance.event_serializer_class).to be_nil
      end
    end

    context 'with STI hierarchy walking' do
      let(:parent_class) do
        Class.new(Spree::Base) do
          self.table_name = 'spree_products'
          include Spree::Publishable
        end
      end

      let(:child_class) do
        Class.new(parent_class) do
          self.table_name = 'spree_products'
        end
      end

      it 'resolves via parent class when child has no serializer' do
        stub_const('Spree::ParentModel', parent_class)
        stub_const('Spree::ChildModel', child_class)
        stub_const('Spree::Api::V3::ParentModelSerializer', v3_serializer_class)

        instance = child_class.new(id: 1)
        expect(instance.event_serializer_class).to eq(v3_serializer_class)
      end
    end

    context 'with model override' do
      let(:override_class) do
        serializer = v3_serializer_class
        Class.new(Spree::Base) do
          self.table_name = 'spree_products'
          include Spree::Publishable

          define_method(:event_serializer_class) { serializer }
        end
      end

      it 'uses the overridden serializer' do
        stub_const('Spree::CustomModel', override_class)
        instance = override_class.new(id: 1)

        expect(instance.event_serializer_class).to eq(v3_serializer_class)
      end
    end

    context 'with anonymous class' do
      it 'returns nil' do
        anon_class = Class.new(Spree::Base) do
          self.table_name = 'spree_products'
          include Spree::Publishable
        end

        instance = anon_class.new(id: 1)
        expect(instance.event_serializer_class).to be_nil
      end
    end
  end

  describe '#event_serializer_params' do
    before do
      stub_const('Spree::TestProduct', publishable_class)
    end

    it 'returns a hash with required keys' do
      params = instance.send(:event_serializer_params)

      expect(params).to include(:store, :currency, :user, :locale, :includes)
      expect(params[:user]).to be_nil
      expect(params[:locale]).to be_nil
      expect(params[:includes]).to eq([])
    end

    context 'when resource has a store method' do
      let(:store) { build(:store) }

      it 'uses the resource store' do
        allow(instance).to receive(:store).and_return(store)
        params = instance.send(:event_serializer_params)

        expect(params[:store]).to eq(store)
      end
    end

    context 'when resource does not have a store method' do
      it 'falls back to Spree::Current.store' do
        current_store = build(:store)
        allow(Spree::Current).to receive(:store).and_return(current_store)
        params = instance.send(:event_serializer_params)

        expect(params[:store]).to eq(current_store)
      end
    end
  end

  describe '#event_prefix' do
    before do
      stub_const('Spree::Product', publishable_class)
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
    end

    it 'enables lifecycle events' do
      expect(lifecycle_class.lifecycle_events_enabled).to be true
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
    end

    it 'derives from model name' do
      expect(Spree::OrderLineItem.event_prefix).to eq('order_line_item')
    end

    it 'can be customized' do
      stub_const('Spree::CustomModel', publishable_class)
      Spree::CustomModel.event_prefix = 'custom'
      expect(Spree::CustomModel.event_prefix).to eq('custom')
    end
  end
end
