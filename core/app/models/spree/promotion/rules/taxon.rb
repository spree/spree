module Spree
  class Promotion
    module Rules
      class Taxon < PromotionRule
        has_and_belongs_to_many :taxons, class_name: '::Spree::Taxon', join_table: 'spree_taxons_promotion_rules', foreign_key: 'promotion_rule_id'

        MATCH_POLICIES = %w(any all)
        preference :match_policy, default: MATCH_POLICIES.first

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          if preferred_match_policy == 'all'
            order_taxons(order).where(id: taxons).count == taxons.count
          else
            order_taxons(order).where(id: taxons).count > 0
          end
        end

        def taxon_ids_string
          taxons.pluck(:id).join(',')
        end

        def taxon_ids_string=(s)
          ids = s.to_s.split(',').map(&:strip)
          taxons << Spree::Taxon.find(ids)
        end

        private
        def order_taxons(order)
          Spree::Taxon.joins(products: {variants: :line_items}).where(spree_line_items: {order_id: order.id})
        end
      end
    end
  end
end
