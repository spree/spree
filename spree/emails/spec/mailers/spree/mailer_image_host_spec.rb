require 'spec_helper'

describe 'image URLs in emails', type: :mailer do
  let(:backend_host) { 'backend.example.com' }
  let(:storefront_origin) { 'https://storefront.example.com' }

  let(:store) { create(:store, url: 'store.example.com') }
  let!(:allowed_origin) { create(:allowed_origin, store: store, origin: storefront_origin) }

  let(:order) { create(:completed_order_with_totals, store: store, email: 'test@example.com') }

  let(:message) { Spree::OrderMailer.confirm_email(order) }
  let(:html_body) { (message.html_part || message).body.to_s }
  let(:image_srcs) { html_body.scan(/<img[^>]+src="([^"]+)"/).flatten }
  let(:active_storage_srcs) { image_srcs.select { |src| src.include?('/rails/active_storage/') } }

  around do |example|
    original_routes_host = Rails.application.routes.default_url_options[:host]
    original_mailer_host = ActionMailer::Base.default_url_options[:host]

    example.run

    Rails.application.routes.default_url_options[:host] = original_routes_host
    ActionMailer::Base.default_url_options[:host] = original_mailer_host
  end

  before do
    store.logo.attach(
      io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
      filename: 'thinking-cat.jpg'
    )

    # Production setup
    Rails.application.routes.default_url_options[:host] = backend_host
  end

  it 'sets the storefront allowed origin as the email link host' do
    message.deliver_now

    expect(ActionMailer::Base.default_url_options[:host]).to eq(storefront_origin)
  end

  it 'generates image urls against the backend application host, not the storefront origin' do
    expect(active_storage_srcs).not_to be_empty
    active_storage_srcs.each do |src|
      expect(src).to include(backend_host)
      expect(src).not_to include('storefront.example.com')
    end
  end

  context 'when Spree.cdn_host is configured' do
    before { allow(Spree).to receive(:cdn_host).and_return('cdn.example.com') }

    it 'prefers the cdn host over both the backend and storefront hosts' do
      active_storage_srcs.each do |src|
        expect(src).to include('cdn.example.com')
        expect(src).not_to include(backend_host)
        expect(src).not_to include('storefront.example.com')
      end
    end
  end
end
