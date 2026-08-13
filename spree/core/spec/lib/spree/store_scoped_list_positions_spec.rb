require 'spec_helper'

# Tripwire for cross-store position bleed: a store-owned model whose
# acts_as_list is not scoped by its store numbers positions across the whole
# table, so creating or reordering rows in one store shifts every other
# store's list (the bug PaymentMethod shipped with). A list scoped by a
# parent that is itself store-owned (product, option_type, collection…) is
# transitively fine.
RSpec.describe 'Store-scoped list positions' do
  it 'every store-owned acts_as_list scopes by store or a parent association' do
    Rails.application.eager_load!

    offenders = Spree.base_class.descendants.select do |model|
      next false if model.abstract_class? || !model.table_exists?
      next false unless model.column_names.include?('store_id')
      next false unless model.include?(ActiveRecord::Acts::List::InstanceMethods)

      # acts_as_list encodes its scope in the generated scope_condition: a
      # scoped list yields a Hash ({store_id: …} or a parent foreign key,
      # which is transitively store-scoped); an unscoped one the literal
      # SQL fragment '1 = 1'.
      model.new.send(:scope_condition) == '1 = 1'
    end

    expect(offenders).to be_empty, lambda {
      "Store-owned models with an unscoped acts_as_list (positions bleed across stores):\n" \
        "#{offenders.map(&:name).join(', ')}\n" \
        'Declare acts_as_list scope: :store_id (see Spree::Collection, Spree::Market, Spree::PriceList).'
    }
  end
end
