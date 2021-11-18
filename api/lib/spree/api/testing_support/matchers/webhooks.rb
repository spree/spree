# Passes if executing the code in the block there is a
# `Spree::Webhooks::Subscribers::QueueRequests.call` method
# call with the given `event` and `body` arguments just once.
#
# @example
#   expect { order.complete }.to emit_webhook_event('order.paid')
#   expect do
#     order.start_processing
#     order.complete
#   end.to emit_webhook_event('order.paid')
#
# It can also be negated, resulting in the expectation
# waiting to not receive a `call` method call with the
# given `event` and `body` (`once` isn't taken into consideration).
#
# @example
#   expect { order.complete }.not_to emit_webhook_event('order.paid')
#   expect do
#     order.start_processing
#     order.complete
#   end.not_to emit_webhook_event('order.paid')
#
# == Notes
#
# The matcher relies on a `body` method previously defined which
# isn't added to the matcher definition, because it acts in a different
# way depending on what's the resource being tested.
#
# The `body` webhook metadata is added right after executing the
# block provided, because it needs to have access to the event
# created after passing the conditions in `queue_webhooks_requests!`
# and before the requests are enqueued.
#
RSpec::Matchers.define :emit_webhook_event do |event_to_emit|
  match do |block|
    queue_requests = instance_double(Spree::Webhooks::Subscribers::QueueRequests)

    allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
    allow(queue_requests).to receive(:call).with(any_args)

    with_webhooks_enabled { block.call }

    Spree::Webhooks::Event.find_by(name: event_to_emit).tap do |event|
      # condition to avoid adding metadata when not emitting webhooks
      if event.present?
        # The webhook metadata must be added after the body is built
        # to get access to the event created on queue_webhooks_requests!.
        body.merge!(
          event_created_at: event.created_at, event_id: event.id, event_type: event.name
        )
      end
    end

    expect(queue_requests).to(
      have_received(:call).with(event: event_to_emit, body: body).once
    )
  end

  def block_body_definition(obj_method)
    # positive look-behinds must have a fixed length, using a straightforward match instead
    obj_method.source.squish[/(expect *({|do) *)(.*?)( *(}|end).(not_)*to)/, 3]
  end

  failure_message do |obj_method|
    block_body_def = block_body_definition(obj_method)
    "Expected that executing `#{block_body_def}` emits the `#{event_to_emit}` Webhook event.\n" \
      "Check that `#{block_body_def}` does implement `queue_webhooks_requests!` for " \
      "`#{event_to_emit}` with the following body: \n\n#{body}."
  end

  failure_message_when_negated do |obj_method|
    "Expected that executing `#{block_body_definition(obj_method)}` does not " \
      "emit the `#{event_to_emit}` Webhook event with the following body: #{body}."
  end

  supports_block_expectations
end

def with_webhooks_enabled
  ENV['DISABLE_SPREE_WEBHOOKS'] = nil
  yield
  ENV['DISABLE_SPREE_WEBHOOKS'] = 'true'
end
