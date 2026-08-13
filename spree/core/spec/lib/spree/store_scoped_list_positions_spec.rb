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

      # acts_as_list encodes its scope in the generated scope_condition. A
      # Hash with store_id or a foreign key counts as scoped (a parent FK is
      # transitively store-scoped); anything else — the unscoped '1 = 1'
      # sentinel, a raw SQL string, or a Hash of non-FK columns like
      # {deleted_at: nil} — is unverifiable here and must be reviewed.
      condition = model.new.send(:scope_condition)
      !(condition.is_a?(Hash) &&
        condition.keys.any? { |key| key.to_s == 'store_id' || key.to_s.end_with?('_id') })
    end

    expect(offenders).to be_empty, lambda {
      "Store-owned models whose acts_as_list scope is missing or not verifiably store-derived " \
        "(positions bleed across stores):\n" \
        "#{offenders.map(&:name).join(', ')}\n" \
        'Declare acts_as_list scope: :store_id or a parent association (see Spree::Collection, Spree::Market, Spree::PriceList).'
    }
  end
end
