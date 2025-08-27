module Spree
  describe Newsletter::Verify do
    subject(:service) { described_class.new(params).call }

    let(:params) do
      {
        subscriber: subscriber
      }
    end

    let(:subscriber) { create(:newsletter_subscriber) }
  end
end