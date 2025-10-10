require 'spec_helper'

RSpec.describe Spree::Themes::ScreenshotJob do
  subject { described_class.perform_now(theme.id) }

  let(:store) { @default_store }
  let(:theme) { create(:theme, store: store) }

  context 'when screenshot_api_token is not set' do
    before do
      Spree.screenshot_api_token = nil
    end

    it 'does not take a screenshot' do
      expect(Net::HTTP).not_to receive(:get_response)
    end
  end

  context 'when screenshot_api_token is set' do
    let(:file) { File.new(Spree::Core::Engine.root + 'spec/fixtures/thinking-cat.jpg') }

    before do
      Spree.screenshot_api_token = 'test_token'

      allow_any_instance_of(Spree::Store).to receive(:url_or_custom_domain).and_return('demo.spreecommerce.org')
      allow(Net::HTTP).to receive(:get_response).and_return(
        instance_double(Net::HTTPResponse, code: '200', body: file.read)
      )
    end

    it 'takes a screenshot' do
      subject

      expect(Net::HTTP).to have_received(:get_response).with(URI("https://shot.screenshotapi.net/v3/screenshot?enable_caching=true&file_type=png&output=image&retina=true&token=test_token&url=demo.spreecommerce.org%253Ftheme_id%253D#{theme.id}"))
      theme.reload

      expect(theme.screenshot.attached?).to be_truthy
      expect(theme.screenshot.filename.to_s).to eq("theme-screenshot-#{theme.id}.png")
    end
  end
end
