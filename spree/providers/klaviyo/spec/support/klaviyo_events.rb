# Builds the Spree event a subscriber receives.
module KlaviyoEvents
  def spree_event(name, payload, metadata: {}, store: @default_store)
    Spree::Event.new(name: name, payload: payload.deep_stringify_keys, metadata: metadata, store_id: store&.id)
  end
end

RSpec.configure do |config|
  config.include KlaviyoEvents
end

# Any of this gem's jobs, ignoring the core jobs that creating records enqueues.
RSpec::Matchers.define :enqueue_a_klaviyo_job do
  supports_block_expectations

  match do |block|
    count = -> { ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job['job_class'].to_s.start_with?('SpreeKlaviyo::') } }
    before = count.call
    block.call
    count.call > before
  end
end
