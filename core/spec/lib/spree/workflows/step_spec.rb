require 'spec_helper'

RSpec.describe Spree::Workflows::Step do
  describe '#initialize' do
    it 'creates a step with id and handler' do
      step = described_class.new(:my_step) do |input, context|
        success({ result: 'done' })
      end

      expect(step.id).to eq('my_step')
      expect(step.handler).to be_a(Proc)
    end

    it 'accepts options' do
      step = described_class.new(:async_step, async: true, batch: true)

      expect(step.async?).to be true
      expect(step.batch?).to be true
    end
  end

  describe '#compensate' do
    it 'sets compensation handler' do
      step = described_class.new(:my_step) { |_, _| }
      step.compensate { |data, context| 'compensated' }

      expect(step.compensatable?).to be true
      expect(step.compensation_handler).to be_a(Proc)
    end

    it 'returns self for chaining' do
      step = described_class.new(:my_step) { |_, _| }
      result = step.compensate { |_, _| }

      expect(result).to eq(step)
    end
  end

  describe '#execute' do
    let(:context) { Spree::Workflows::Context.new }

    it 'executes handler and returns StepResponse' do
      step = described_class.new(:my_step) do |input, context|
        success({ value: input[:x] * 2 })
      end

      response = step.execute({ x: 5 }, context)

      expect(response).to be_a(Spree::Workflows::StepResponse)
      expect(response.output[:value]).to eq(10)
    end

    it 'wraps hash return in StepResponse' do
      step = described_class.new(:my_step) do |input, context|
        { value: 'raw hash' }
      end

      response = step.execute({}, context)

      expect(response).to be_a(Spree::Workflows::StepResponse)
      expect(response.output[:value]).to eq('raw hash')
    end

    it 'wraps non-hash return in StepResponse' do
      step = described_class.new(:my_step) do |input, context|
        'string result'
      end

      response = step.execute({}, context)

      expect(response.output[:result]).to eq('string result')
    end

    it 'raises StepFailedError on exception' do
      step = described_class.new(:failing_step) do |input, context|
        raise 'Something went wrong'
      end

      expect { step.execute({}, context) }.to raise_error(Spree::Workflows::StepFailedError, 'Something went wrong')
    end

    it 'raises RetryableError when retry! is called' do
      step = described_class.new(:retryable_step) do |input, context|
        retry!(StandardError.new('Temporary failure'))
      end

      expect { step.execute({}, context) }.to raise_error(Spree::Workflows::RetryableError)
    end
  end

  describe '#compensate!' do
    let(:context) { Spree::Workflows::Context.new }

    it 'executes compensation handler' do
      compensated = false
      step = described_class.new(:my_step) { |_, _| }
      step.compensate { |data, context| compensated = true }

      step.compensate!({ order_id: 1 }, context)

      expect(compensated).to be true
    end

    it 'passes compensation data to handler' do
      received_data = nil
      step = described_class.new(:my_step) { |_, _| }
      step.compensate { |data, context| received_data = data }

      step.compensate!({ order_id: 123 }, context)

      expect(received_data[:order_id]).to eq(123)
    end

    it 'does nothing without compensation handler' do
      step = described_class.new(:my_step) { |_, _| }

      expect { step.compensate!({}, context) }.not_to raise_error
    end

    it 'raises CompensationError on failure' do
      step = described_class.new(:my_step) { |_, _| }
      step.compensate { |_, _| raise 'Compensation failed' }

      expect { step.compensate!({}, context) }.to raise_error(Spree::Workflows::CompensationError)
    end
  end

  describe '#async?' do
    it 'returns true when async option is set' do
      step = described_class.new(:async_step, async: true) { |_, _| }
      expect(step.async?).to be true
    end

    it 'returns false by default' do
      step = described_class.new(:sync_step) { |_, _| }
      expect(step.async?).to be false
    end
  end

  describe '#batch?' do
    it 'returns true when batch option is set' do
      step = described_class.new(:batch_step, batch: true) { |_, _| }
      expect(step.batch?).to be true
    end

    it 'returns false by default' do
      step = described_class.new(:normal_step) { |_, _| }
      expect(step.batch?).to be false
    end
  end
end
