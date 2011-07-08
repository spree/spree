require 'spree_core'
require 'spree_promo_hooks'

module SpreePromo
  class Engine < Rails::Engine

    def self.activate

      Adjustment.class_eval do
        scope :promotion, lambda { where('label LIKE ?', "#{I18n.t(:promotion)}%") }
      end

      # put class_eval and other logic that depends on classes outside of the engine inside this block
      Product.class_eval do
        has_and_belongs_to_many :promotion_rules

        def possible_promotions
          rules_with_matching_product_groups = product_groups.map(&:promotion_rules).flatten
          all_rules = promotion_rules + rules_with_matching_product_groups
          promotion_ids = all_rules.map(&:activator_id).uniq
          Promotion.advertised.where(:id => promotion_ids)
        end
      end

      ProductGroup.class_eval do
        has_many :promotion_rules
      end

      Order.class_eval do

        attr_accessible :coupon_code
        attr_accessor :coupon_code

        def promotion_credit_exists?(promotion)
          !! adjustments.promotion.reload.detect { |credit| credit.originator.promotion.id == promotion.id }
        end

        def products
          line_items.map {|li| li.variant.product}
        end

        def update_adjustments_with_promotion_limiting
          update_adjustments_without_promotion_limiting
          return if adjustments.promotion.eligible.none?
          most_valuable_adjustment = adjustments.promotion.eligible.max{|a,b| a.amount.abs <=> b.amount.abs}
          ( adjustments.promotion.eligible - [most_valuable_adjustment] ).each{|adjustment| adjustment.update_attribute_without_callbacks(:eligible, false)}
        end

        alias_method_chain :update_adjustments, :promotion_limiting

      end


      OrdersController.class_eval do

        def update
          @order = current_order
          if @order.update_attributes(params[:order])

            if @order.coupon_code.present?
              fire_event('spree.checkout.coupon_code_added', :coupon_code => @order.coupon_code)
            end

            @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
            fire_event('spree.order.contents_changed')
            respond_with(@order) { |format| format.html { redirect_to cart_path } }
          else
            respond_with(@order)
          end
        end

      end

      # Keep a record ot all static page paths visited for promotions that require them
      ContentController.class_eval do
        after_filter :store_visited_path
        def store_visited_path
          session[:visited_paths] ||= []
          session[:visited_paths] = (session[:visited_paths]  + [params[:path]]).compact.uniq
        end
      end

      # Include list of visited paths in notification payload hash
      SpreeBase::InstanceMethods.class_eval do
        def default_notification_payload
          {:user => current_user, :order => current_order, :visited_paths => session[:visited_paths]}
        end
      end

      if Activator.table_exists?
        # register promotion rules and actions
        [Promotion::Rules::ItemTotal,
         Promotion::Rules::Product,
         Promotion::Rules::User,
         Promotion::Rules::FirstOrder,
         Promotion::Rules::LandingPage,
         Promotion::Rules::UserLoggedIn,
         Promotion::Actions::CreateAdjustment,
         Promotion::Actions::CreateLineItems
        ].each &:register

        # register default promotion calculators
        [
          Calculator::FlatPercentItemTotal,
          Calculator::FlatRate,
          Calculator::FlexiRate,
          Calculator::PerItem,
          Calculator::FreeShipping
        ].each{|c_model|
          begin
            Promotion::Actions::CreateAdjustment.register_calculator(c_model) if c_model.table_exists?
          rescue Exception => e
            $stderr.puts "Error registering promotion calculator #{c_model}"
          end
        }
      end

    end

    config.autoload_paths += %W(#{config.root}/lib)
    config.to_prepare &method(:activate).to_proc
  end
end
