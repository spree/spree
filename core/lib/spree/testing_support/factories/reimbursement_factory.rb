FactoryGirl.define do
  factory :reimbursement, class: Spree::Reimbursement do
    ignore do
      reimbursement_items_count 1
    end

    customer_return { create(:customer_return_with_accepted_items, line_items_count: reimbursement_items_count) }

    before(:create) do |reimbursement, evaluator|
      reimbursement.order ||= reimbursement.customer_return.order
      if reimbursement.reimbursement_items.empty?
        reimbursement.customer_return.return_items.each do |return_item|
          reimbursement.reimbursement_items.build({
            inventory_unit_id:   return_item.inventory_unit_id,
            return_item_id:      return_item.id,
            exchange_variant_id: return_item.exchange_variant_id,
            pre_tax_amount:      return_item.pre_tax_amount,
          })
        end
      end
    end
  end
end
