require 'spec_helper'

describe Spree::Emails::TemplateResolver do
  let(:app_views) { Pathname.new(Dir.mktmpdir) }
  let(:gem_views) { Pathname.new(Dir.mktmpdir) }
  let(:key) { 'spree/order_mailer/confirm_email' }

  after { [app_views, gem_views].each { |dir| FileUtils.remove_entry(dir) } }

  def write(root, file)
    path = root.join(file)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, '')
    path.to_s
  end

  def resolver(legacy:)
    described_class.new([app_views, gem_views], app_view_path: app_views, legacy: legacy)
  end

  before { write(gem_views, "#{key}.liquid") }

  it "falls back to the gem's Liquid template" do
    expect(resolver(legacy: false).find(key).path).to eq(gem_views.join("#{key}.liquid").to_s)
  end

  it "prefers the app's Liquid template over everything" do
    app_liquid = write(app_views, "#{key}.liquid")
    write(app_views, "#{key}.html.erb")

    expect(resolver(legacy: true).find(key).path).to eq(app_liquid)
  end

  context 'with an ERB view at the same path' do
    let!(:erb) { write(app_views, "#{key}.html.erb") }

    it 'renders it while spree_legacy_emails is installed' do
      expect(resolver(legacy: true).find(key)).to have_attributes(path: erb, erb?: true)
    end

    it 'ignores it otherwise' do
      expect(resolver(legacy: false).find(key)).not_to be_erb
    end
  end

  it 'refuses a key that could leave the view paths' do
    expect { resolver(legacy: false).find('../secrets') }.to raise_error(described_class::InvalidKey)
  end

  describe Spree::Emails::LegacyTemplates do
    it "lists the app's ERB email views Spree no longer renders" do
      write(app_views, 'spree/order_mailer/confirm_email.html.erb')
      write(app_views, 'spree/shared/_base_mailer_footer.html.erb')
      write(app_views, 'spree/products/show.html.erb')

      expect(described_class.ignored_overrides(app_views)).to eq(
        %w[spree/order_mailer/confirm_email.html.erb spree/shared/_base_mailer_footer.html.erb]
      )
    end
  end
end
