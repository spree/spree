require 'spec_helper'

describe Spree::EmailTemplates::RestoreRevision do
  include_context 'with an editable email template'

  let(:store) { @default_store }
  let(:template) { create(:email_template, store: store, key: editable_key) }
  let(:revision) { create(:email_template_revision, email_template: template, subject: 'Old subject', body: 'Old body') }

  it 'copies the revision into the draft, to publish like any change' do
    draft = described_class.new.call(revision: revision).value

    expect(draft).to have_attributes(key: editable_key, subject: 'Old subject', body: 'Old body')
    expect(template.reload.body).not_to eq('Old body')
  end
end
