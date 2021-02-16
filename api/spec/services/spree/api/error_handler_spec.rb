require 'spec_helper'

module Spree
  describe Api::ErrorHandler do
    class CustomException < StandardError
      def backtrace
        ['a', 'b']
      end
    end

    let(:message) { 'error' }
    let(:exception) { CustomException.new(message) }
    let(:user) { create :user }

    subject { described_class.call(exception: exception, opts: { user: user }) }
    let(:result) { subject }

    it 'returns result with error' do
      expect(Rails.logger).to receive(:error).with(message)
      expect(Rails.logger).to receive(:error).with("User ID: #{user.id}")
      expect(Rails.logger).to receive(:error).with(exception.backtrace.join("\n"))

      expect(result.value).to eq({ exception: exception, message: message })
    end
  end
end
