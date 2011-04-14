require 'spree_core'
require 'spree_promo_hooks'

module SpreePromo
  class Engine < Rails::Engine
    def self.activate
      # put class_eval and other logic that depends on classes outside of the engine inside this block
      Product.class_eval do
        has_and_belongs_to_many :promotion_rules

        def possible_promotions
          rules_with_matching_product_groups = product_groups.map(&:promotion_rules).flatten
          all_rules = promotion_rules + rules_with_matching_product_groups
          promotion_ids = all_rules.map(&:promotion_id).uniq
          Promotion.automatic.scoped(:conditions => {:id => promotion_ids})
        end
      end

      ProductGroup.class_eval do
        has_many :promotion_rules
      end

      Order.class_eval do

        has_many :promotion_credits, :conditions => "source_type='Promotion'", :dependent => :destroy

        attr_accessible :coupon_code
        attr_accessor :coupon_code
        before_save :process_coupon_code, :if => "@coupon_code.present?"

        def promotion_credit_exists?(credit)
          promotion_credits.reload.detect { |c| c.source_id == credit.id }
        end

        def process_coupon_code
          coupon = Promotion.find(:first, :conditions => ["UPPER(code) = ?", @coupon_code.upcase])
          if coupon
            coupon.create_discount(self)
          end
        end

        def products
          line_items.map {|li| li.variant.product}
        end

        def update_totals(force_adjustment_recalculation=false)
          self.payment_total = payments.completed.map(&:amount).sum
          self.item_total = line_items.map(&:amount).sum

          process_automatic_promotions

          if force_adjustment_recalculation
            applicable_adjustments, adjustments_to_destroy = adjustments.partition{|a| a.applicable?}
            self.adjustments = applicable_adjustments
            adjustments_to_destroy.each(&:destroy)
          end

          self.adjustment_total = self.adjustments.map(&:amount).sum
          self.total            = self.item_total   + self.adjustment_total
        end


        def process_automatic_promotions
          # recalculate amount
          self.promotion_credits.each do |credit|
            if credit.source.eligible?(self)
              amount = -credit.source.calculator.compute(self).abs
              if credit.amount != amount
                # avoid infinite callbacks
                PromotionCredit.update_all("amount = #{amount}", { :id => credit.id })
              end
            else
              credit.destroy
            end
          end
          
          current_promotions = self.promotion_credits.map(&:source)
          # return if current promotions can not be combined
          return if current_promotions.any? { |promotion| !promotion.combine? }
          
          new_promotions = eligible_automatic_promotions - current_promotions
          new_promotions.each do |promotion|
            next if current_promotions.present? && !promotion.combine?
            amount = promotion.calculator.compute(self).abs
            amount = item_total if amount > item_total
            if amount > 0
              self.promotion_credits.create(
                  :source => promotion,
                  :amount => -amount,
                  :label  => promotion.name
                )
            end
          end
        end

        def eligible_automatic_promotions
          @eligible_automatic_coupons ||= Promotion.automatic.select{|c| c.eligible?(self)}
        end
      end

      if File.basename( $0 ) != "rake"
        # register promotion rules
        [Promotion::Rules::ItemTotal, Promotion::Rules::Product, Promotion::Rules::User, Promotion::Rules::FirstOrder].each &:register

        # register default promotion calculators
        [
          Calculator::FlatPercentItemTotal,
          Calculator::FlatRate,
          Calculator::FlexiRate,
          Calculator::PerItem,
          Calculator::FreeShipping
        ].each{|c_model|
          begin
            Promotion.register_calculator(c_model) if c_model.table_exists?
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
