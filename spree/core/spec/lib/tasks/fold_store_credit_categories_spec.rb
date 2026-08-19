require 'spec_helper'
require 'rake'

describe 'spree:upgrade:fold_store_credit_categories' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'fold_store_credit_categories.rake')
  end

  let(:legacy_category) { Class.new(ActiveRecord::Base) { self.table_name = 'spree_store_credit_categories' } }
  let(:goodwill) { legacy_category.create!(name: 'Goodwill') }

  def run_task
    task = Rake::Task['spree:upgrade:fold_store_credit_categories']
    task.reenable
    old = $stdout.dup
    $stdout.reopen(File::NULL, 'w')
    task.invoke
  ensure
    $stdout.reopen(old)
  end

  it 'copies the category name into a blank memo and keeps admin-written memos' do
    blank = create(:store_credit, memo: nil)
    written = create(:store_credit, memo: 'Broken vase')
    blank.update_columns(category_id: goodwill.id)
    written.update_columns(category_id: goodwill.id)

    run_task

    expect(blank.reload.memo).to eq('Goodwill')
    expect(written.reload.memo).to eq('Broken vase')

    run_task
    expect(blank.reload.memo).to eq('Goodwill')
  end
end
