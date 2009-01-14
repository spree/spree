# stub frameworks like to gum up Object, so this is deliberately
# set NOT to run so that you don't accidentally run it when you
# run this dir.

# To run it, stand in this directory and say:
#
#   RUN_FLEXMOCK_EXAMPLE=true ruby ../bin/spec mocking_with_flexmock.rb

if ENV['RUN_FLEXMOCK_EXAMPLE']
  Spec::Runner.configure do |config|
    config.mock_with :flexmock
  end

  describe "Flexmocks" do
    it "should fail when the expected message is received with wrong arguments" do
      m = flexmock("now flex!")
      m.should_receive(:msg).with("arg").once
      m.msg("other arg")
    end

    it "should fail when the expected message is not received at all" do
      m = flexmock("now flex!")
      m.should_receive(:msg).with("arg").once
    end
  end
end
