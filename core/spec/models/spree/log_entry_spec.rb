require 'spec_helper'

describe Spree::LogEntry, type: :model do
  let(:log_entry) { create(:log_entry, details: details) }
  let(:details) { "--- !ruby/object:ActiveMerchant::Billing::Response\nparams: {}\nmessage: 'Bogus Gateway: Forced success'\nsuccess: true\ntest: true\nauthorization: \nfraud_review: \nerror_code: \nemv_authorization: \nnetwork_transaction_id: \navs_result:\n  code: \n  message: \n  street_match: \n  postal_match: \ncvv_result:\n  code: \n  message: \n" }

  describe '#parsed_details' do
    subject { log_entry.parsed_details }

    it 'deserializes log entry with billing response' do
      expect(subject).to be_instance_of(ActiveMerchant::Billing::Response)
      expect(subject.message).to eq('Bogus Gateway: Forced success')
    end
  end
end
