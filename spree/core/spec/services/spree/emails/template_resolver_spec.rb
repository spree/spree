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

    expect(resolver.find_partial('greeting').path).to eq(partial)
  end

  describe 'with a store' do
    include_context 'with an editable email template'

    let(:store) { @default_store }
    let(:views) { [Spree::Core::Engine.root.join('app/views')] }
    let(:german) { described_class.new(views, store: store, locale: 'de') }

    it "puts the store's published version in front of the file" do
      create(:email_template, store: store, key: editable_key, body: 'Stored')

      expect(german.find(editable_key).body).to eq('Stored')
      expect(german.find_default(editable_key).path).to end_with("#{editable_key}.liquid")
    end

    it "prefers the email's language over the version for every language" do
      create(:email_template, store: store, key: editable_key, body: 'Any')
      create(:email_template, store: store, key: editable_key, locale: 'de', body: 'German')

      expect(german.find(editable_key).body).to eq('German')
      expect(described_class.new(views, store: store, locale: 'fr').find(editable_key).body).to eq('Any')
    end

    it 'ignores a reverted version' do
      create(:email_template, store: store, key: editable_key, body: 'Stored', status: :reverted)

      expect(german.find(editable_key).path).to end_with("#{editable_key}.liquid")
    end

    it 'never reads the store for a template merchants may not edit' do
      expect(described_class.new(views, store: store).find('spree/webhook_mailer/endpoint_disabled').path).to be_present
    end

    it 'puts an unsaved draft in front of everything' do
      create(:email_template, store: store, key: editable_key, body: 'Stored')
      draft = Spree::Emails::Template.new(key: editable_key, subject: 'S', body: 'Draft')

      expect(described_class.new(views, store: store, drafts: { editable_key => draft }).find(editable_key).body).to eq('Draft')
    end
  end

  it 'refuses a key that could leave the view paths' do
    expect { resolver.find('../secrets') }.to raise_error(described_class::InvalidKey)
  end
end
