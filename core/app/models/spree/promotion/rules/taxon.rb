module Spree
  class Promotion
    module Rules
      class Taxon < PromotionRule
        #
        # Associations
        #
        has_many :promotion_rule_taxons, class_name: 'Spree::PromotionRuleTaxon',
                                         foreign_key: 'promotion_rule_id',
                                         dependent: :destroy
        has_many :taxons, through: :promotion_rule_taxons, class_name: 'Spree::Taxon'

        #
        # Preferences
        #
        MATCH_POLICIES = %w(any all)
        preference :match_policy, default: MATCH_POLICIES.first

        #
        # Attributes
        #
        attr_accessor :taxon_ids_to_add

        #
        # Callbacks
        #
        after_save :add_taxons

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible_taxon_ids
          @eligible_taxon_ids ||= promotion_rule_taxons.pluck(:taxon_id)
        end

        def eligible?(order, _options = {})
          return true if eligible_taxon_ids.empty?

          if preferred_match_policy == 'all'
            order_taxon_ids_with_ancestors = taxon_ids_in_order_including_ancestors(order)
            unless eligible_taxon_ids.all? { |id| order_taxon_ids_with_ancestors.include?(id) }
              eligibility_errors.add(:base, eligibility_error_message(:missing_taxon))
            end
          else
            order_taxon_ids_with_ancestors = taxon_ids_in_order_including_ancestors(order)
            unless eligible_taxon_ids.any? { |id| order_taxon_ids_with_ancestors.include?(id) }
              eligibility_errors.add(:base, eligibility_error_message(:no_matching_taxons))
            end
          end

          eligibility_errors.empty?
        end

        def actionable?(line_item)
          Spree::Classification.where(taxon_id: eligible_taxon_ids_including_children, product_id: line_item.product_id).exists?
        end

        def taxon_ids_string
          ActiveSupport::Deprecation.warn(
            'Please use `taxon_ids=` instead.'
          )
          taxons.pluck(:id).join(',')
        end

        def taxon_ids_string=(s)
          ActiveSupport::Deprecation.warn(
            'Please use `taxon_ids=` instead.'
          )
          ids = s.to_s.split(',').map(&:strip)
          self.taxons = Spree::Taxon.for_stores(stores).find(ids)
        end

        private

        # IDs of taxons in rule including all their children
        def eligible_taxon_ids_including_children
          @eligible_taxon_ids_including_children ||= begin
            return [] if eligible_taxon_ids.empty?

            Spree::Taxon.where(id: eligible_taxon_ids).flat_map(&:cached_self_and_descendants_ids).uniq
          end
        end

        # IDs of taxons in order that match rule taxons (or their children), plus all ancestors
        def taxon_ids_in_order_including_ancestors(order)
          # Get taxon IDs from order products that are within rule taxons or their children
          order_taxon_ids = Spree::Classification.where(product_id: order.product_ids, taxon_id: eligible_taxon_ids_including_children).pluck(:taxon_id).uniq

          return [] if order_taxon_ids.empty?

          # Get those taxons plus all their ancestors
          Spree::Taxon.where(id: order_taxon_ids).flat_map { |taxon| taxon.self_and_ancestors.ids }.uniq
        end

        def add_taxons
          return if taxon_ids_to_add.nil?

          promotion_rule_taxons.delete_all
          promotion_rule_taxons.insert_all(
            taxon_ids_to_add.map { |taxon_id| { taxon_id: taxon_id, promotion_rule_id: id } }
          ) if taxon_ids_to_add.any?

          # Clear memoized values
          @eligible_taxon_ids = nil
          @eligible_taxon_ids_including_children = nil
        end
      end
    end
  end
end
