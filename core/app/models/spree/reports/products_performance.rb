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
    class ProductsPerformance < Spree::Report
      def line_items_scope
        line_items_scope = Spree::LineItem.
                           select("
                             quantity,
                             (quantity * price) + #{Spree::LineItem.table_name}.adjustment_total AS gross_sales,
                             #{Spree::LineItem.table_name}.promo_total,
                             #{Spree::LineItem.table_name}.included_tax_total + #{Spree::LineItem.table_name}.additional_tax_total AS tax_total,
                             quantity * price AS amount,
                             #{Spree::Variant.table_name}.product_id AS product_id
                           ").
                           joins(:variant, :order).
                           where(
                             spree_line_items: {
                               currency: currency
                             },
                             spree_orders: {
                               completed_at: (date_from.to_time.beginning_of_day)..(date_to.to_time.end_of_day)
                             }
                           )

        return Spree::Product.none if line_items_scope.empty?

        line_items_sql = line_items_scope.to_sql

        product_scope = store.products
        product_scope = product_scope.where(vendor_id: vendor.id) if vendor.present?

        product_scope.includes(:taxons, :tax_category, variants: :prices, master: :prices).
                              joins("LEFT JOIN (#{line_items_sql}) AS line_items ON #{Spree::Product.table_name}.id = line_items.product_id").
                              select("
                                spree_products.*,
                                COALESCE(SUM(line_items.quantity), 0) AS sales_count,
                                COALESCE(SUM(line_items.amount), 0.0) AS sales_total,
                                COALESCE(SUM(line_items.gross_sales), 0.0) AS total,
                                COALESCE(SUM(line_items.promo_total), 0.0) AS discount_total,
                                COALESCE(SUM(line_items.tax_total), 0.0) AS tax
                              ").group('spree_products.id')
      end

      def to_partial_path
        'spree/admin/reports/products_performance'
      end
    end
  end
end
