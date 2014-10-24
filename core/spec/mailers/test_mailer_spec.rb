require 'spec_helper'
require 'email_spec'

describe Spree::TestMailer, :type => :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:user) { create(:user) }

  context ":from not set explicitly" do
    it "falls back to spree config" do
      message = Spree::TestMailer.test_email(user)
      expect(message.from).to eq([Spree::Config[:mails_from]])
    end
  end

  it "confirm_email accepts a user id as an alternative to a User object" do
    expect(Spree.user_class).to receive(:find).with(user.id).and_return(user)
    expect {
      test_email = Spree::TestMailer.test_email(user.id)
    }.not_to raise_error
  end
end