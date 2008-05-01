# stub frameworks like to gum up Object, so this is deliberately
# set NOT to run so that you don't accidentally run it when you
# run this dir.

# To run it, stand in this directory and say:
#
#   RUN_RR_EXAMPLE=true ruby ../bin/spec mocking_with_rr.rb

if ENV['RUN_RR_EXAMPLE']
  Spec::Runner.configure do |config|
    config.mock_with :rr
  end
  describe "RR framework" do
    it "should should be made available by saying config.mock_with :rr" do
      o = Object.new
      mock(o).msg("arg")
      o.msg
    end
    it "should should be made available by saying config.mock_with :rr" do
      o = Object.new
      mock(o) do |m|
        m.msg("arg")
      end
      o.msg
    end
  end
end
