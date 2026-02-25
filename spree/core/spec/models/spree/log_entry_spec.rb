require 'spec_helper'

describe Spree::LogEntry, type: :model do
  let(:log_entry) { create(:log_entry, details: details) }
  let(:details) { Spree::PaymentResponse.new(true, 'Bogus Gateway: Forced success', {}, test: true).to_yaml }

  describe '#parsed_details' do
    subject { log_entry.parsed_details }

    it 'deserializes log entry with payment response' do
      expect(subject).to be_instance_of(Spree::PaymentResponse)
      expect(subject.message).to eq('Bogus Gateway: Forced success')
    end
  end
end
