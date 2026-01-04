require 'spec_helper'

RSpec.describe Spree::Workflows::StepResponse do
  describe '.success' do
    it 'creates a successful response' do
      response = described_class.success({ order_id: 1 })

      expect(response.success?).to be true
      expect(response.failure?).to be false
      expect(response.output[:order_id]).to eq(1)
    end

    it 'stores compensation data' do
      response = described_class.success({ order_id: 1 }, { rollback_data: 'xyz' })

      expect(response.compensation_data[:rollback_data]).to eq('xyz')
    end

    it 'uses output as compensation data if not provided' do
      response = described_class.success({ order_id: 1 })

      expect(response.compensation_data[:order_id]).to eq(1)
    end
  end

  describe '.failure' do
    it 'creates a failed response' do
      response = described_class.failure('Something went wrong')

      expect(response.success?).to be false
      expect(response.failure?).to be true
      expect(response.error).to eq('Something went wrong')
    end

    it 'stores compensation data' do
      response = described_class.failure('Error', { partial_data: 'abc' })

      expect(response.compensation_data[:partial_data]).to eq('abc')
    end

    it 'returns nil for output' do
      response = described_class.failure('Error')

      expect(response.output).to be_nil
    end
  end

  describe '.permanent_failure' do
    it 'creates a permanent failure response' do
      response = described_class.permanent_failure('Critical error')

      expect(response).to be_a(Spree::Workflows::PermanentFailureResponse)
      expect(response.failure?).to be true
      expect(response.permanent?).to be true
    end
  end

  describe 'indifferent access' do
    it 'allows symbol and string access to output' do
      response = described_class.success({ 'order_id' => 1 })

      expect(response.output[:order_id]).to eq(1)
      expect(response.output['order_id']).to eq(1)
    end

    it 'allows symbol and string access to compensation_data' do
      response = described_class.success({}, { 'rollback_id' => 5 })

      expect(response.compensation_data[:rollback_id]).to eq(5)
      expect(response.compensation_data['rollback_id']).to eq(5)
    end
  end
end
