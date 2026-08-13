# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeOpenTelemetry::Subscribers do
  before(:all) { described_class.attach! }
  after(:all) { described_class.detach! }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  def finished_spans
    SPREE_OTEL_TEST_EXPORTER.finished_spans
  end

  def build_workflow(&block)
    workflow = Class.new(Spree::Workflow) do
      def self.name = 'Spree::Testing::TracedWorkflow'
      workflow_key 'testing.traced_workflow'
      class_eval(&block)
    end
    stub_const('Spree::Testing::TracedWorkflow', workflow)
    workflow
  end

  describe 'workflow spans' do
    it 'nests step spans under the workflow span, marking external steps as client calls' do
      workflow = build_workflow do
        def perform(subject:)
          super
          step :prepare
          external_step :call_carrier
          success(subject)
        end

        private

        def prepare = nil
        def call_carrier = nil
      end

      workflow.call(subject: 1)

      perform_span = finished_spans.find { |span| span.name == 'testing.traced_workflow' }
      prepare_span = finished_spans.find { |span| span.name == 'testing.traced_workflow prepare' }
      carrier_span = finished_spans.find { |span| span.name == 'testing.traced_workflow call_carrier' }

      expect(perform_span.attributes).to include('spree.workflow.outcome' => 'success')
      expect(prepare_span.parent_span_id).to eq(perform_span.span_id)
      expect(prepare_span.kind).to eq(:internal)
      expect(carrier_span.kind).to eq(:client)
      expect(carrier_span.attributes).to include('spree.workflow.step.external' => true)
    end

    it 'marks failed workflows and their failing step errored' do
      workflow = build_workflow do
        def perform(subject:)
          super
          step :explode
          success(subject)
        end

        private

        def explode = failure(:exploded, 'boom')
      end

      workflow.call(subject: 1)

      perform_span = finished_spans.find { |span| span.name == 'testing.traced_workflow' }
      step_span = finished_spans.find { |span| span.name == 'testing.traced_workflow explode' }

      expect(perform_span.attributes).to include('spree.workflow.outcome' => 'failure')
      expect(perform_span.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
      expect(step_span.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
      # Control-flow signal, not a real exception — no exception event.
      expect(step_span.events.to_a).to be_empty
    end

    it 'treats a halted workflow as successful' do
      workflow = build_workflow do
        def perform(subject:)
          super
          step :bail
          success(:never_reached)
        end

        private

        def bail = halt!(:early)
      end

      expect(workflow.call(subject: 1).value).to eq(:early)

      perform_span = finished_spans.find { |span| span.name == 'testing.traced_workflow' }
      step_span = finished_spans.find { |span| span.name == 'testing.traced_workflow bail' }

      expect(perform_span.attributes).to include('spree.workflow.outcome' => 'success')
      expect(perform_span.status.code).not_to eq(OpenTelemetry::Trace::Status::ERROR)
      expect(step_span.status.code).not_to eq(OpenTelemetry::Trace::Status::ERROR)
    end

    it 'records real step exceptions on the span' do
      workflow = build_workflow do
        def perform(subject:)
          super
          step :broken
          success(subject)
        end

        private

        def broken = raise(ArgumentError, 'bad input')
      end

      expect { workflow.call(subject: 1) }.to raise_error(ArgumentError)

      step_span = finished_spans.find { |span| span.name == 'testing.traced_workflow broken' }
      expect(step_span.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
      expect(step_span.events.map(&:name)).to include('exception')
    end

    it 'spans hook dispatch only when handlers are registered' do
      workflow = build_workflow do
        hooks :after_thing

        def perform(subject:)
          super
          run_hooks :after_thing
          success(subject)
        end
      end

      workflow.call(subject: 1)
      expect(finished_spans.map(&:name)).not_to include('testing.traced_workflow hooks after_thing')

      Spree.hooks.register('testing.traced_workflow.after_thing') { |_context| nil }
      workflow.call(subject: 2)

      hook_span = finished_spans.find { |span| span.name == 'testing.traced_workflow hooks after_thing' }
      expect(hook_span.attributes).to include('spree.hook' => 'after_thing', 'spree.hook.handler_count' => 1)
    end
  end

  describe 'webhook delivery spans' do
    it 'creates a client span carrying the response code' do
      ActiveSupport::Notifications.instrument(
        'deliver.spree_webhooks', event_name: 'order.placed', url_host: 'hooks.example.com'
      ) do |payload|
        payload[:response_code] = 200
      end

      span = finished_spans.sole
      expect(span.name).to eq('spree.webhook.deliver order.placed')
      expect(span.kind).to eq(:client)
      expect(span.attributes).to include(
        'spree.webhook.event' => 'order.placed',
        'server.address' => 'hooks.example.com',
        'http.response.status_code' => 200
      )
      expect(span.status.code).not_to eq(OpenTelemetry::Trace::Status::ERROR)
    end

    it 'marks failed deliveries errored' do
      ActiveSupport::Notifications.instrument(
        'deliver.spree_webhooks', event_name: 'order.placed', url_host: 'hooks.example.com'
      ) do |payload|
        payload[:error_type] = 'timeout'
      end

      expect(finished_spans.sole.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
    end

    it 'marks 4xx/5xx responses errored' do
      ActiveSupport::Notifications.instrument(
        'deliver.spree_webhooks', event_name: 'order.placed', url_host: 'hooks.example.com'
      ) do |payload|
        payload[:response_code] = 500
      end

      span = finished_spans.sole
      expect(span.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
      expect(span.status.description).to eq('HTTP 500')
    end
  end

  describe 'gateway spans' do
    it 'creates a client span named after the gateway action' do
      ActiveSupport::Notifications.instrument(
        'gateway.spree_payments', action: 'purchase', payment_method_type: 'Spree::Gateway::Bogus'
      ) { nil }

      span = finished_spans.sole
      expect(span.name).to eq('spree.gateway.purchase')
      expect(span.kind).to eq(:client)
      expect(span.attributes).to include(
        'spree.gateway.action' => 'purchase',
        'spree.gateway.payment_method_type' => 'Spree::Gateway::Bogus'
      )
    end
  end

  describe 'events dispatch spans' do
    it 'creates an internal span per subscriber dispatch' do
      ActiveSupport::Notifications.instrument(
        'dispatch.spree_events', event_name: 'order.placed', subscriber: 'MySubscriber', async: true
      ) { nil }

      span = finished_spans.sole
      expect(span.name).to eq('order.placed dispatch')
      expect(span.attributes).to include(
        'spree.event.name' => 'order.placed',
        'spree.event.subscriber' => 'MySubscriber',
        'spree.event.async' => true
      )
    end
  end

  describe 'domain events' do
    it 'surfaces published Spree events as span events on the current span, without payloads' do
      event = Spree::Event.new(name: 'order.placed', payload: { 'email' => 'private@example.com' })

      SpreeOpenTelemetry.tracer.in_span('outer') do
        ActiveSupport::Notifications.instrument('order.placed.spree', event: event) { nil }
      end

      outer = finished_spans.find { |span| span.name == 'outer' }
      span_event = outer.events.to_a.sole
      expect(span_event.name).to eq('spree.event order.placed')
      expect(span_event.attributes.keys).to eq(['spree.event.id'])
    end
  end
end
