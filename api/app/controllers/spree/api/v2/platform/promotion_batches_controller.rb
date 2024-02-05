module Spree
  module Api
    module V2
      module Platform
        class PromotionBatchesController < ResourceController
          def create
            template_promotion = Spree::Promotion.find(params[:promotion_batch][:template_promotion_id])
            promotion_batch = Spree::PromotionBatches::CreateWithRandomCodes.new.call(
              template_promotion: template_promotion,
              amount: params[:promotion_batch][:amount].to_i,
              random_characters: params[:promotion_batch][:random_characters].to_i,
              prefix: params[:promotion_batch][:prefix],
              suffix: params[:promotion_batch][:suffix]
            )

            render_serialized_payload { promotion_batch }
          end

          def csv_export
            send_data Spree::PromotionBatches::Export.new.call(promotion_batch: resource),
                      filename: "promo_codes_from_batch_id_#{params[:id]}.csv",
                      disposition: :attachment,
                      type: 'text/csv'
          end

          def import
            template_promotion = Spree::Promotion.find(params[:promotion_batch][:template_promotion_id])
            promotion_batch = Spree::PromotionBatches::CreateWithCodes.new.call(
              template_promotion: template_promotion,
              codes: params[:promotion_batch][:codes]
            )

            render_serialized_payload { promotion_batch }
          end

          private

          def model_class
            Spree::PromotionBatch
          end

          def spree_permitted_attributes
            [:template_promotion_id]
          end
        end
      end
    end
  end
end
