require 'spec_helper'

describe Spree::EmailTemplates::Publish do
  include_context 'with an editable email template'

  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:body) { '<mj-section><mj-column><mj-text>Hi {{ user.first_name }}</mj-text></mj-column></mj-section>' }

  before { create(:email_template_draft, store: store, key: editable_key, subject: 'Reset', body: body) }

  def publish
    described_class.new.call(store: store, key: editable_key, actor: admin)
  end

  it 'makes the draft live, records a revision and clears the draft' do
    template = publish.value

    expect(template).to be_published
    expect(template.body).to eq(body)
    expect(template.published_by).to eq(admin)
    expect(template.revisions.count).to eq(1)
    expect(store.email_template_drafts.count).to eq(0)
  end

  it 'refuses a draft that does not render, saying what is wrong and where' do
    store.email_template_drafts.first.update!(body: "<mj-section>\n<mj-column><mj-text>{{ user.nickname }}</mj-text></mj-column></mj-section>")

    result = publish

    expect(result).not_to be_success
    expect(result.error.value).to eq(:invalid_template)
    expect(result.value).to contain_exactly(hash_including(email: editable_key, line: 2, message: /nickname/))
    expect(store.email_templates.count).to eq(0)
  end

  it 'refuses a draft saved after the one the admin reviewed' do
    store.email_template_drafts.first.update!(body: "#{body} changed")

    result = described_class.new.call(store: store, key: editable_key, actor: admin, lock_version: 0)

    expect(result.error.value).to eq(:stale)
    expect(store.email_templates.count).to eq(0)
  end

  it "checks a layout draft in every language the store published an email in" do
    allow_any_instance_of(Spree::Store).to receive(:supported_locales_list).and_return(%w[de en])
    store.email_template_drafts.destroy_all
    create(:email_template, store: store, key: editable_key, locale: 'de',
                            body: '<mj-section><mj-column><mj-text>{{ nur_deutsch }}</mj-text></mj-column></mj-section>')
    layout = File.read(Spree::Core::Engine.root.join('app/views/layouts/spree/base_mailer.liquid'))
    create(:email_template_draft, store: store, key: 'layouts/spree/base_mailer', body: layout)

    result = described_class.new.call(store: store, key: 'layouts/spree/base_mailer', actor: admin)

    expect(result.value).to contain_exactly(hash_including(message: /nur_deutsch/))
  end

  it 'refuses when there is no draft' do
    store.email_template_drafts.destroy_all

    expect(publish.error.value).to eq(:no_draft)
  end

  it 'publishes again over a reverted version, keeping its history' do
    template = publish.value
    template.update!(status: :reverted)
    create(:email_template_draft, store: store, key: editable_key, body: body)

    republished = publish.value

    expect(republished.id).to eq(template.id)
    expect(republished).to be_published
    expect(republished.revisions.count).to eq(2)
  end
end
