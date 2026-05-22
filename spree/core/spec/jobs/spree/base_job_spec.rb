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
end
