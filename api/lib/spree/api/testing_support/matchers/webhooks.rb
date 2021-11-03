RSpec::Matchers.define :emit_webhook_event do |event_to_emit|
  match do |obj_method|
    ENV['DISABLE_SPREE_WEBHOOKS'] = nil

    queue_requests = instance_double(Spree::Webhooks::Subscribers::QueueRequests)

    allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
    allow(queue_requests).to receive(:call).with(any_args)

    obj_method.call
    expect(queue_requests).to have_received(:call).with(event: event_to_emit, body: body).once

    ENV['DISABLE_SPREE_WEBHOOKS'] = 'true'
  end

  def block_body_definition(obj_method)
    # positive look-behinds must have a fixed length, using straighforward match instead
    obj_method.source.squish[/(expect *({|do) *)(.*?)( *(}|end).(not_)*to)/, 3]
  end

  failure_message do |obj_method|
    block_body_def = block_body_definition(obj_method)
    "Expected that executing `#{block_body_def}` emits the `#{event_to_emit}` Webhook event.\n" \
      "Check that `#{block_body_def}` does implement `queue_webhooks_requests!` for " \
      "`#{event_to_emit}` with the following body: #{body}."
  end

  failure_message_when_negated do |obj_method|
    "Expected that executing `#{block_body_definition(obj_method)}` does not " \
      "emit the `#{event_to_emit}` Webhook event with the following body: #{body}."
  end

  supports_block_expectations
end
