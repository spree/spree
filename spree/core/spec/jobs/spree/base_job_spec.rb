require 'spec_helper'

RSpec.describe Spree::BaseJob, type: :job do
  # Pins the default retry/discard policy that every Spree job inherits. Anyone
  # changing this is making a global behavior change — the test failure is the
  # signal to think about whether that's intentional.
  describe 'default retry policy' do
    let(:retry_handler_classes) do
      described_class.rescue_handlers.map { |class_or_name, _handler| class_or_name }
    end

    it 'retries on transient DB infrastructure errors' do
      expect(retry_handler_classes).to include(
        'ActiveRecord::Deadlocked',
        'ActiveRecord::LockWaitTimeout',
        'ActiveRecord::ConnectionNotEstablished',
        'ActiveRecord::ConnectionFailed'
      )
    end

    it 'retries on RecordNotFound to absorb the Sidekiq enqueue-vs-commit race' do
      expect(retry_handler_classes).to include('ActiveRecord::RecordNotFound')
    end

    it 'discards on ActiveJob::DeserializationError' do
      expect(retry_handler_classes).to include('ActiveJob::DeserializationError')
    end

    it 'does NOT broadly retry on StandardError (each job opts in explicitly)' do
      expect(retry_handler_classes).not_to include('StandardError')
    end
  end

  # ActiveJob handler lookup is reverse-declaration-order. A subclass that declares
  # `retry_on StandardError` shadows the parent's `discard_on ActiveJob::DeserializationError`
  # (since DeserializationError < StandardError) unless the subclass re-declares the
  # discard *after* its retry. These jobs intentionally do broad retry and must
  # re-declare the discard to keep deserialization failures from retrying forever.
  describe 'broad-retry subclasses re-declare discard_on DeserializationError' do
    # Loading the API gem job from the core spec context: the spec_helper boots the
    # core dummy app, which doesn't load spree_api, so reference it conditionally.
    job_classes = [
      'Spree::SearchProvider::IndexJob',
      'Spree::SearchProvider::RemoveJob',
      'Spree::Events::SubscriberJob'
    ]

    job_classes.each do |class_name|
      it "#{class_name} discards DeserializationError instead of retrying" do
        klass = class_name.constantize
        last_matching = klass.rescue_handlers.reverse_each.detect do |class_or_name, _|
          rescued = class_or_name.is_a?(String) ? class_or_name.constantize : class_or_name
          rescued >= ActiveJob::DeserializationError
        end
        expect(last_matching&.first.to_s).to eq('ActiveJob::DeserializationError'),
          "expected #{class_name} to discard DeserializationError, but the most-recently-declared " \
          "matching handler is for #{last_matching&.first.inspect}. Re-declare " \
          "`discard_on ActiveJob::DeserializationError` AFTER `retry_on StandardError`."
      end
    end
  end
end
