require 'spec_helper'

RSpec.describe SpreeStripe::UpdateCustomerJob do
  subject { described_class.new.perform(customer_id) }

  let(:customer) { create(:customer) }
  let(:customer_id) { customer.id }

  it 'calls the SpreeStripe::UpdateCustomer service' do
    expect(SpreeStripe::UpdateCustomer).to receive_message_chain(:new, :call).with(customer: customer)
    subject
  end

  context 'when the customer is not found' do
    let(:customer_id) { 'missing' }

    it 'does nothing' do
      expect(SpreeStripe::UpdateCustomer).not_to receive(:new)
      subject
    end
  end
end
