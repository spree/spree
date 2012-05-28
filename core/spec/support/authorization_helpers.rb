module AuthorizationHelpers
  def stub_authorization!
    before do
      controller.should_receive(:authorize!).twice.and_return(true)
    end
  end
end

RSpec.configure do |config|
  config.extend AuthorizationHelpers
end
