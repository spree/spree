module Spree
  module Api
    module V2
      module Platform
        class PromotionRuleSerializer < BaseSerializer
          include ResourceSerializerConcern

          attributes :user_id, :product_group_id

          attribute :preferences do |promotion_rule|
            promotion_rule.preferences
          end

          belongs_to :promotion

          has_many :products, through: :product_promotion_rules, class_name: 'Spree::Product', if: proc { |record|
                                                                                                     record.respond_to?(:promotion_action_line_items)
                                                                                                   }
          has_many :users, through: :promotion_rule_users, class_name: "::#{Spree.user_class}", if: proc { |record|
                                                                                                      record.respond_to?(:promotion_rule_users)
                                                                                                    }
          has_many :taxons, through: :promotion_rule_taxons, class_name: 'Spree::Taxon', if: proc { |record|
                                                                                               record.respond_to?(:promotion_rule_taxons)
                                                                                             }
        end
      end
    end
  end
end
