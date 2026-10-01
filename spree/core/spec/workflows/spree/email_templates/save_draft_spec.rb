require 'spec_helper'

describe Spree::EmailTemplates::SaveDraft do
  include_context 'with an editable email template'

  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }

  def save(attributes, **options)
    described_class.new.call(store: store, key: editable_key, attributes: attributes, actor: admin, **options)
  end

  it "starts from Spree's default and remembers it" do
    draft = save({ body: '<mj-section></mj-section>' }).value

    default = File.read(Spree::Core::Engine.root.join("app/views/#{editable_key}.liquid"))
    expect(draft.body).to eq('<mj-section></mj-section>')
    expect(default).to include(draft.base_body.strip)
    expect(draft.subject).to include('password_reset_email.subject')
    expect(draft.updated_by).to eq(admin)
  end

  it 'starts from the published version when the store has one' do
    create(:email_template, store: store, key: editable_key, subject: 'Published', base_body: 'Old default')

    draft = save({ body: 'x' }).value

    expect(draft.subject).to eq('Published')
    expect(draft.base_body).to eq('Old default')
  end

  it "starts a shared partial from its file" do
    Spree.editable_email_templates.register('spree/shared/summary_row', kind: :partial)
    path = Rails.root.join('app/views/spree/shared/_summary_row.liquid')
    FileUtils.mkdir_p(path.dirname)
    File.write(path, '<mj-text>{{ label }}</mj-text>')

    draft = described_class.new.call(store: store, key: 'spree/shared/summary_row', attributes: { subject: nil }).value

    expect(draft.body).to eq('<mj-text>{{ label }}</mj-text>')
  ensure
    Spree.editable_email_templates.delete('spree/shared/summary_row')
    FileUtils.rm_f(path)
  end

  it "rebases onto Spree's current default when asked, keeping the merchant's body" do
    create(:email_template, store: store, key: editable_key, body: 'Mine', base_body: 'Old default')

    draft = save({ rebase: true }).value

    expect(draft.body).to eq('Mine')
    expect(draft.default_changed?(Spree::Emails::TemplateResolver.new(Spree::BaseMailer.view_paths.paths.map(&:path)).find_default(editable_key))).to be(false)
  end

  it 'refuses a save made from a stale copy' do
    draft = save({ body: 'first' }).value
    save({ body: 'second', lock_version: draft.lock_version })

    result = save({ body: 'stale', lock_version: draft.lock_version })

    expect(result).not_to be_success
    expect(result.error.value).to eq(:stale)
    expect(draft.reload.body).to eq('second')
  end

  it 'refuses a template merchants may not edit' do
    result = described_class.new.call(store: store, key: 'spree/webhook_mailer/endpoint_disabled', attributes: { body: 'x' })

    expect(result.error.value).to eq(:not_editable)
  end
end
