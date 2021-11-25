# Passes if executing the code in the block there is a
# `Spree::Webhooks::Subscribers::QueueRequests.call` method
# call with the given `event` and `webhook_payload_body` arguments just once.
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
# given `event` and `webhook_payload_body` (`once` isn't taken into consideration).
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
# The matcher relies on a `webhook_payload_body` method previously defined which
# isn't added to the matcher definition, because it acts in a different
# way depending on what's the resource being tested.
#
RSpec::Matchers.define :emit_webhook_event do |event_to_emit|
  match do |block|
    queue_requests = instance_double(Spree::Webhooks::Subscribers::QueueRequests)

    allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
    allow(queue_requests).to receive(:call).with(any_args)

    with_webhooks_enabled { Timecop.freeze { block.call } }

    expect(queue_requests).to(
      have_received(:call).with(event_name: event_to_emit, webhook_payload_body: webhook_payload_body.to_json).once
    )
  end

  def block_definition(obj_method)
    # positive look-behinds must have a fixed length, using a straightforward match instead
    obj_method.source.squish[/(expect *({|do) *)(.*?)( *(}|end).(not_)*to)/, 3]
  end

  failure_message do |obj_method|
    block_def = block_definition(obj_method)
    "Expected that executing `#{block_def}` emits the `#{event_to_emit}` Webhook event.\n" \
      "Check that `#{block_def}` does implement `queue_webhooks_requests!` for " \
      "`#{event_to_emit}` with the following webhook_payload_body: \n\n#{webhook_payload_body}."
  end

  failure_message_when_negated do |obj_method|
    "Expected that executing `#{block_definition(obj_method)}` does not " \
      "emit the `#{event_to_emit}` Webhook event with the following webhook_payload_body: #{webhook_payload_body}."
  end

  supports_block_expectations
end

def with_webhooks_enabled
  ENV['DISABLE_SPREE_WEBHOOKS'] = nil
  yield
  ENV['DISABLE_SPREE_WEBHOOKS'] = 'true'
end
