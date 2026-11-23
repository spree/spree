require 'spec_helper'

RSpec.describe Spree::PaymentSetupSessions::Adyen do
  it 'loads under its stored name' do
    setup_session = create(:adyen_payment_setup_session)

    expect(Spree::PaymentSetupSession.find(setup_session.id)).to be_a(described_class)
  end
end
