module Spree
  module Admin
    class DashboardController < BaseController
      include Spree::Admin::AnalyticsConcern

      before_action :set_analytics_defaults, only: %i[analytics]
      before_action :load_vendor
      before_action :clear_return_to, only: %i[show]

      def show
        @breadcrumb_icon = 'home'
        add_breadcrumb Spree.t(:home), spree.admin_dashboard_path
      end

      def getting_started
        @breadcrumb_icon = 'map'
        add_breadcrumb Spree.t('admin.getting_started'), spree.admin_getting_started_path
      end

      def analytics
        @orders_scope = current_store.orders.complete.where(currency: params[:analytics_currency])
        @products_scope = current_store.products

        if defined?(Spree::Vendor)
          # for vendors we need to count there sub-orders
          # for admins we need to counnt only the main orders (the ones that are splitted)
          @orders_scope = if @vendor.present?
                            @orders_scope.with_vendor(@vendor.id)
                          elsif @orders_scope.respond_to?(:without_vendor)
                            @orders_scope.without_vendor
                          end
        end

        load_top_products

        sales_total_sum = @orders_scope.where(completed_at: analytics_time_range).sum(:total)
        @sales_total = Spree::Money.new(sales_total_sum, currency: params[:analytics_currency])
        previous_sales_total = @orders_scope.where(completed_at: previous_analytics_time_range).sum(:total)
        @sales_growth_rate = calc_growth_rate(sales_total_sum, previous_sales_total)

        @orders_total = @orders_scope.where(completed_at: analytics_time_range).count
        previous_orders_total = @orders_scope.where(completed_at: previous_analytics_time_range).count
        @orders_growth_rate = calc_growth_rate(@orders_total, previous_orders_total)

        orders_avg = @orders_scope.where(completed_at: analytics_time_range).average(:total).to_f
        @orders_average = Spree::Money.new(orders_avg, currency: params[:analytics_currency])
        previous_orders_average = @orders_scope.where(completed_at: previous_analytics_time_range).average(:total).to_f
        @orders_average_growth_rate = calc_growth_rate(orders_avg, previous_orders_average)

        @grouped_orders_scope = if same_day?
                                  @orders_scope.group_by_hour(:completed_at, range: analytics_time_range, time_zone: current_store.preferred_timezone,
                                                                             default_value: 0.0)
                                else
                                  @orders_scope.group_by_day(:completed_at, range: analytics_time_range, time_zone: current_store.preferred_timezone,
                                                                            default_value: 0.0)
                                end

        load_analytics_data
      end

      # PATCH /admin/dashboard/dismiss_enterprise_edition_notice
      def dismiss_enterprise_edition_notice
        session[:spree_enterprise_edition_notice_dismissed] = true
        redirect_back(fallback_location: spree.admin_dashboard_path)
      end

      # PATCH /admin/dashboard/dismiss_updater_notice
      def dismiss_updater_notice
        session[:spree_updater_notice_dismissed] = { value: true, expires_at: 7.days.from_now }
        redirect_back(fallback_location: spree.admin_dashboard_path)
      end

      private

      def load_vendor
        return unless defined?(Spree::Vendor)

        @vendor = current_vendor || (Spree::Vendor.find(params[:vendor_id]) if params[:vendor_id].present?)
      end

      def load_top_products
        line_items_grouped = Spree::LineItem.
                             select('
                              sum(quantity) AS all_quantity,
                              sum(quantity * price) AS all_amount,
                              spree_variants.product_id AS variant_product_id
                            ').
                             joins(:variant).
                             where(order: current_store.orders.complete.where('spree_orders.currency': params[:analytics_currency]).where('spree_orders.completed_at': analytics_time_range)).
                             order('all_amount desc, all_quantity desc').
                             group('variant_product_id')

        line_items_grouped = line_items_grouped.joins(:product).where('spree_products.vendor_id': @vendor.id) if @vendor.present?
        line_items_grouped = line_items_grouped.limit(5)

        product_ids = line_items_grouped.map(&:variant_product_id).uniq.compact

        if product_ids.empty?
          @top_products = []
          return
        end

        products = current_store.products.with_deleted.includes(:master, :variants).where(id: product_ids)

        @top_products = line_items_grouped.map do |li|
          product = products.find { |p| p.id == li.variant_product_id }
          next unless product.present?

          {
            product: product,
            quantity: li.all_quantity,
            amount: Spree::Money.new(li.all_amount, currency: params[:analytics_currency])
          }
        end.compact
      end

      def load_analytics_data
        return if @vendor.present?

        @audience_scope = Spree.user_class.where(created_at: analytics_time_range)
        @audience_total = @audience_scope.count
        previous_audience_total = Spree.user_class.where(created_at: previous_analytics_time_range).count
        @audience_growth_rate = calc_growth_rate(@audience_total, previous_audience_total)

        @audience = if same_day?
                      @audience_scope.group_by_hour(:created_at, range: analytics_time_range, time_zone: current_store.preferred_timezone,
                                                                 default_value: 0)
                    else
                      @audience_scope.group_by_day(:created_at, range: analytics_time_range, time_zone: current_store.preferred_timezone,
                                                                default_value: 0)
                    end

        return unless defined?(Ahoy)

        @visits_scope = Ahoy::Visit.where(started_at: analytics_time_range)
        @visits_total = @visits_scope.count
        previous_visits_total = Ahoy::Visit.where(started_at: previous_analytics_time_range).count
        @visits_growth_rate = calc_growth_rate(@visits_total, previous_visits_total)

        @visits = if same_day?
                    @visits_scope.group_by_hour(:started_at, range: analytics_time_range, time_zone: current_store.preferred_timezone,
                                                             default_value: 0)
                  else
                    @visits_scope.group_by_day(:started_at, range: analytics_time_range, time_zone: current_store.preferred_timezone,
                                                            default_value: 0)
                  end

        @top_landing_pages = @visits_scope.where.not(landing_page: [nil, '']).top(:landing_page, 10)
        excluded_domains = current_store.respond_to?(:custom_domains) ? current_store.custom_domains.pluck(:url) : []
        @top_referrers = @visits_scope.where.not(referring_domain: excluded_domains << current_store.url).top(
          :referring_domain, 10
        )
        @top_locations = @visits_scope.top(:country, 10)
        @top_devices = @visits_scope.group(:device_type).count.transform_keys do |device|
          device.nil? ? 'N/A' : device
        end.map { |series| [series.first, (series.second.to_f / @visits_scope.count) * 100] }
      end
    end
  end
end
