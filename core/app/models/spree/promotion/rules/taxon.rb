module Spree
  class Promotion
    module Rules
      class Taxon < PromotionRule
        has_many :promotion_rule_taxons, class_name: 'Spree::PromotionRuleTaxon',
                                         foreign_key: 'promotion_rule_id',
                                         dependent: :destroy
        has_many :taxons, through: :promotion_rule_taxons, class_name: 'Spree::Taxon'

        MATCH_POLICIES = %w(any all)
        preference :match_policy, default: MATCH_POLICIES.first

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, _options = {})
          if preferred_match_policy == 'all'
            unless (taxons.to_a - taxons_in_order_including_parents(order)).empty?
              eligibility_errors.add(:base, eligibility_error_message(:missing_taxon))
            end
          else
            order_taxons = taxons_in_order_including_parents(order)
            unless taxons.any? { |taxon| order_taxons.include? taxon }
              eligibility_errors.add(:base, eligibility_error_message(:no_matching_taxons))
            end
          end

          eligibility_errors.empty?
        end

        def actionable?(line_item)
          store = line_item.order.store

          store.products.
            joins(:classifications).
            where(Spree::Classification.table_name => { taxon_id: taxon_ids, product_id: line_item.product_id }).
            exists?
        end

        def taxon_ids_string
          taxons.pluck(:id).join(',')
        end

        def taxon_ids_string=(s)
          ids = s.to_s.split(',').map(&:strip)
          self.taxons = Spree::Taxon.for_stores(stores).find(ids)
        end

        private

        # All taxons in an order
        def order_taxons(order)
          taxon_ids = Spree::Classification.where(product_id: order.product_ids).pluck(:taxon_id).uniq

          order.store.taxons.where(id: taxon_ids)
        end

        # ids of taxons rules and taxons rules children
        def taxons_including_children_ids
          taxons.inject([]) { |ids, taxon| ids += taxon.self_and_descendants.ids }
        end

        # taxons order vs taxons rules and taxons rules children
        def order_taxons_in_taxons_and_children(order)
          order_taxons(order).where(id: taxons_including_children_ids)
        end

        def taxons_in_order_including_parents(order)
          order_taxons_in_taxons_and_children(order).inject([]) { |taxons, taxon| taxons << taxon.self_and_ancestors }.flatten.uniq
        end
      end
    end
  end
end
