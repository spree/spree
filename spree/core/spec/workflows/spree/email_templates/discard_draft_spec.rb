require 'spec_helper'

describe Spree::EmailTemplates::DiscardDraft do
  include_context 'with an editable email template'

  let(:store) { @default_store }
  let!(:draft) { create(:email_template_draft, store: store, key: editable_key) }

  it 'throws the draft away' do
    described_class.new.call(store: store, key: editable_key, lock_version: 0)

    expect(store.email_template_drafts.count).to eq(0)
  end

  it 'keeps a draft saved after the one the admin saw' do
    draft.update!(body: 'Newer')

    expect(described_class.new.call(store: store, key: editable_key, lock_version: 0).error.value).to eq(:stale)
    expect(store.email_template_drafts.count).to eq(1)
  end
end
