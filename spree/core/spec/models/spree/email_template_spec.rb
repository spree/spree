require 'spec_helper'

describe Spree::EmailTemplate, type: :model do
  include_context 'with an editable email template'

  let(:store) { @default_store }

  it 'only accepts templates merchants may edit' do
    template = build(:email_template, store: store, key: 'spree/webhook_mailer/endpoint_disabled')

    expect(template).not_to be_valid
    expect(template.errors[:key]).to be_present
  end

  it 'stores the version for every language as "any", never empty' do
    expect(create(:email_template, store: store, locale: '').locale).to eq('any')
  end

  it 'keeps one version per template and language' do
    create(:email_template, store: store)

    expect(build(:email_template, store: store)).not_to be_valid
    expect(build(:email_template, store: store, locale: 'de')).to be_valid
  end

  describe '#default_changed?' do
    let(:template) { build(:email_template, base_subject: 'S', base_body: 'B') }

    it 'is true once the default it started from changes' do
      expect(template.default_changed?(Spree::Emails::Template.new(key: 'k', subject: 'S', body: 'B'))).to be(false)
      expect(template.default_changed?(Spree::Emails::Template.new(key: 'k', subject: 'S', body: 'New'))).to be(true)
    end
  end
end
