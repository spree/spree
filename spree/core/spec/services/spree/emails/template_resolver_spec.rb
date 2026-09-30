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

  it 'refuses a key that could leave the view paths' do
    expect { resolver.find('../secrets') }.to raise_error(described_class::InvalidKey)
  end

  describe Spree::Emails::ErbOverrides do
    it "lists the app's ERB overrides of Spree's emails, and nothing of the app's own" do
      write(app_views, 'spree/order_mailer/confirm_email.html.erb')
      write(app_views, 'spree/shared/_base_mailer_footer.html.erb')
      write(app_views, 'spree/shared/_mailer_button.html.erb')
      write(app_views, 'spree/custom_mailer/welcome_email.html.erb')

      expect(described_class.ignored(app_views, [gem_views])).to eq(
        %w[spree/order_mailer/confirm_email.html.erb spree/shared/_base_mailer_footer.html.erb]
      )
    end
  end
end
