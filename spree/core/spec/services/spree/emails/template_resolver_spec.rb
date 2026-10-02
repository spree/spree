require 'spec_helper'

describe Spree::Emails::TemplateResolver do
  let(:app_views) { Pathname.new(Dir.mktmpdir) }
  let(:gem_views) { Pathname.new(Dir.mktmpdir) }
  let(:key) { 'spree/order_mailer/confirm_email' }
  let(:resolver) { described_class.new([app_views, gem_views]) }

  after { [app_views, gem_views].each { |dir| FileUtils.remove_entry(dir) } }

  def write(root, file)
    path = root.join(file)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, '')
    path.to_s
  end

  before { write(gem_views, "#{key}.liquid") }

  it "falls back to the gem's template" do
    expect(resolver.find(key).path).to eq(gem_views.join("#{key}.liquid").to_s)
  end

  it "prefers the app's template" do
    app_liquid = write(app_views, "#{key}.liquid")

    expect(resolver.find(key).path).to eq(app_liquid)
  end

  it 'never picks up an ERB view' do
    write(app_views, "#{key}.html.erb")

    expect(resolver.find(key).path).to end_with('.liquid')
  end

  it 'finds a partial named without a folder' do
    partial = write(gem_views, '_greeting.liquid')

    expect(resolver.find_partial('greeting')).to eq(partial)
  end

  it 'refuses a key that could leave the view paths' do
    expect { resolver.find('../secrets') }.to raise_error(described_class::InvalidKey)
  end
end
