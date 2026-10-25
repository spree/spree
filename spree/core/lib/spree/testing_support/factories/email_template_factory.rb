FactoryBot.define do
  factory :email_template, class: Spree::EmailTemplate do
    store { Spree::Store.default || create(:store) }
    key { 'spree/admin_user_mailer/password_reset_email' }
    locale { 'any' }
    subject { 'Reset {{ store.name }}' }
    body { '<mj-section><mj-column><mj-text>Hello</mj-text></mj-column></mj-section>' }
    base_subject { 'Reset {{ store.name }}' }
    base_body { '<mj-section><mj-column><mj-text>Default</mj-text></mj-column></mj-section>' }
    published_at { Time.current }
  end

  factory :email_template_draft, class: Spree::EmailTemplateDraft do
    store { Spree::Store.default || create(:store) }
    key { 'spree/admin_user_mailer/password_reset_email' }
    locale { 'any' }
    subject { 'Reset {{ store.name }}' }
    body { '<mj-section><mj-column><mj-text>Draft</mj-text></mj-column></mj-section>' }
    base_subject { 'Reset {{ store.name }}' }
    base_body { '<mj-section><mj-column><mj-text>Default</mj-text></mj-column></mj-section>' }
  end

  factory :email_template_revision, class: Spree::EmailTemplateRevision do
    email_template
    subject { 'Reset {{ store.name }}' }
    body { '<mj-section><mj-column><mj-text>Hello</mj-text></mj-column></mj-section>' }
  end
end
