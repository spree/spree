require 'spec_helper'
require 'email_spec'

describe Spree::TestMailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:user) { create(:user) }

  context ":from not set explicitly" do
    it "falls back to spree config" do
      message = Spree::TestMailer.test_email(user)
      message.from.should == [Spree::Config[:mails_from]]
    end
  end

  it "confirm_email accepts a user id as an alternative to a User object" do
    Spree.user_class.should_receive(:find).with(user.id).and_return(user)
    lambda {
      test_email = Spree::TestMailer.test_email(user.id)
    }.should_not raise_error
  end
end