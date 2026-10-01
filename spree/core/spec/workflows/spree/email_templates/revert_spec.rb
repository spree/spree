require 'spec_helper'

describe Spree::EmailTemplates::Revert do
  include_context 'with an editable email template'

  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let!(:template) { create(:email_template, store: store, key: editable_key) }

  before do
    create(:email_template_revision, email_template: template)
    create(:email_template_draft, store: store, key: editable_key)
  end

  it 'marks the published version reverted, discards the draft and keeps the history' do
    described_class.new.call(store: store, key: editable_key, actor: admin)

    expect(template.reload).to be_reverted
    expect(template.reverted_by).to eq(admin)
    expect(template.revisions.count).to eq(1)
    expect(store.email_template_drafts.count).to eq(0)
  end

  it 'keeps a draft saved after the one the admin saw' do
    store.email_template_drafts.first.update!(body: 'Newer')

    result = described_class.new.call(store: store, key: editable_key, actor: admin, lock_version: 0)

    expect(result.error.value).to eq(:stale)
    expect(template.reload).to be_published
  end
end
