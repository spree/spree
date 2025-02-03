# == Schema Information
#
# Table name: spree_reports
#
#  id            :bigint           not null, primary key
#  currency      :string
#  date_from     :datetime
#  date_to       :datetime
#  search_params :jsonb
#  type          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  project_id    :bigint           not null
#  store_id      :bigint           not null
#  user_id       :bigint
#  vendor_id     :bigint
#
module Spree
  module Reports
    class SalesTotal < Spree::Report
      def line_items_scope
        store.line_items.where(
          order: Spree::Order.complete.where(
            currency: currency,
            completed_at: (date_from.to_time.beginning_of_day)..(date_to.to_time.end_of_day)
          )
        ).includes(:order, variant: :product)
      end
    end
  end
end
