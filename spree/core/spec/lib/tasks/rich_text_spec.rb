require 'spec_helper'
require 'rake'

describe 'spree:sanitize_rich_text' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:sanitize_rich_text' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'rich_text.rake')
  end

  before { subject.reenable }

  let(:store) { Spree::Store.default || create(:store) }
  # +update_columns+ writes past the sanitizing callback to reproduce
  # pre-upgrade rows.
  let!(:product) { create(:product, store: store).tap { |p| p.update_columns(description: '<p>hi</p><script>alert(1)</script>') } }

  it 'sanitizes stored descriptions' do
    subject.invoke

    expect(product.reload.description).not_to include('<script')
  end

  it 'sanitizes stored translation descriptions' do
    translation = product.translations.create!(locale: 'fr', description: '<p>bonjour</p>')
    translation.update_columns(description: '<p>bonjour</p><script>alert(1)</script>')

    subject.invoke

    expect(translation.reload.description).not_to include('<script')
  end

  it 'leaves clean rows untouched' do
    clean = create(:product, store: store, description: '<p>clean</p>')

    expect { subject.invoke }.not_to change { clean.reload.updated_at }
  end

  it 'does not clobber an edit made after the row was read' do
    allow(Spree::RichTextSanitizer).to receive(:sanitize).and_wrap_original do |original, html|
      product.update_columns(description: '<p>edited elsewhere</p>')
      original.call(html)
    end

    subject.invoke

    expect(product.reload.description).to eq('<p>edited elsewhere</p>')
  end
end
