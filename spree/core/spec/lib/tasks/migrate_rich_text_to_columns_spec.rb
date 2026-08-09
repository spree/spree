require 'spec_helper'
require 'rake'

describe 'spree:migrate_rich_text_to_columns' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:migrate_rich_text_to_columns' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'migrate_rich_text_to_columns.rake')
  end

  before { subject.reenable }

  let(:store) { Spree::Store.default || create(:store) }

  # Pre-6.0 rows live in Action Text, so they're written directly — the models
  # store rich text in their own columns now and no longer create these.
  def legacy_rich_text(record, name, body, locale: nil)
    ActionText::RichText.create!(
      name: name, body: body, record_type: record.class.name, record_id: record.id,
      **(locale ? { locale: locale } : {})
    )
  end

  describe 'category descriptions' do
    let!(:category) { create(:category, store: store) }

    it 'copies the body into the description column' do
      legacy_rich_text(category, 'description', '<p>Legacy <strong>copy</strong></p>')

      subject.invoke

      expect(category.reload.description).to eq('<p>Legacy <strong>copy</strong></p>')
    end

    it 'sanitizes on the way in' do
      legacy_rich_text(category, 'description', '<p>ok</p><script>alert(1)</script>')

      subject.invoke

      expect(category.reload.description).to eq('<p>ok</p>')
    end

    it 'leaves a description already in the column alone when no Action Text row exists' do
      category.update!(description: '<p>Already migrated</p>')

      subject.invoke

      expect(category.reload.description).to eq('<p>Already migrated</p>')
    end

    it 'routes a non-default locale row to the translation table' do
      store.update!(supported_locales: 'en,fr')
      legacy_rich_text(category, 'description', '<p>Bonjour</p>', locale: 'fr')

      subject.invoke

      translation = category.translations.find_by(locale: 'fr')
      expect(translation.description).to eq('<p>Bonjour</p>')
    end

    it 'is idempotent' do
      legacy_rich_text(category, 'description', '<p>Once</p>')
      subject.invoke
      subject.reenable

      expect { subject.invoke }.not_to change { category.reload.updated_at }
      expect(category.reload.description).to eq('<p>Once</p>')
    end

    it 'skips an Action Text row whose record no longer exists' do
      legacy_rich_text(category, 'description', '<p>Orphan</p>')
      category.really_destroy! if category.respond_to?(:really_destroy!)

      expect { subject.invoke }.not_to raise_error
    end
  end

  describe 'policy bodies' do
    let!(:policy) { create(:policy, owner: store) }

    it 'copies the body into the body column' do
      legacy_rich_text(policy, 'body', '<p>Terms</p>')

      subject.invoke

      expect(policy.reload.body).to eq('<p>Terms</p>')
    end
  end

  describe 'order internal notes' do
    let!(:order) { create(:order, store: store) }

    it 'copies the note into the internal_note column' do
      legacy_rich_text(order, 'internal_note', '<p>Called the customer</p>')

      subject.invoke

      expect(order.reload.internal_note).to eq('<p>Called the customer</p>')
    end
  end

  describe 'customer internal notes' do
    let!(:customer) { create(:user) }

    it 'copies the note into the internal_note column' do
      legacy_rich_text(customer, 'internal_note', '<p>VIP</p>')

      subject.invoke

      expect(customer.reload.internal_note).to eq('<p>VIP</p>')
    end

    # migrate_users_to_customers leaves action_text_rich_texts alone, so rows
    # written before that step are still typed as the pre-6.0 user class.
    it 'finds a note still typed under the legacy user class' do
      # Inserted directly: Spree::User is gone in 6.0, so Action Text can't
      # resolve the polymorphic owner well enough to build the record.
      ActionText::RichText.insert!(
        {
          name: 'internal_note', body: '<p>Legacy type</p>', locale: 'en',
          record_type: 'Spree::User', record_id: customer.id,
          created_at: Time.current, updated_at: Time.current
        }
      )

      subject.invoke

      expect(customer.reload.internal_note).to eq('<p>Legacy type</p>')
    end
  end
end
