module Spree
  module Api
    module V2
      module Platform
        class PromotionBatchesController < ResourceController
          def create
            super
          rescue ActiveRecord::InvalidForeignKey => e
            render json: { error: e.message }, status: :unprocessable_entity
          end

          def destroy
            result = destroy_service.call(promotion_batch: resource)

            if result.success?
              head 204
            else
              render_error_payload(result.error)
            end
          end

          def csv_export
            send_data Spree::PromotionBatches::PromotionCodesExporter.new(params).call,
                      filename: "promo_codes_from_batch_id_#{params[:id]}.csv",
                      disposition: :attachment,
                      type: 'text/csv'
          end

          def csv_import
            file = params[:file]
            Spree::PromotionBatches::PromotionCodesImporter.new(file: file, promotion_batch_id: params[:id]).call
            render json: { message: Spree.t('code_upload') }, status: :ok
          rescue Spree::PromotionBatches::PromotionCodesImporter::Error => e
            render json: { error: e.message }, status: :unprocessable_entity
          end

          def populate
            batch_id = params[:id]
            options = {
              batch_size: params[:batch_size].to_i,
              affix: params.dig(:code, :affix)&.to_sym,
              content: params[:affix_content],
              deny_list: params[:forbidden_phrases].split,
              random_part_bytes: params[:random_part_bytes].to_i
            }

            Spree::Promotions::PopulatePromotionBatch.new(batch_id, options).call
              render json: { message: Spree.t('promotion_batch_populated') }, status: :ok
            rescue Spree::Promotions::PopulatePromotionBatch::TemplateNotFoundError => e
              render json: { error: e.message }, status: :unprocessable_entity
          end

          private

          def model_class
            Spree::PromotionBatch
          end

          def scope_includes
            [:promotion]
          end

          def spree_permitted_attributes
            [:template_promotion_id]
          end

          def destroy_service
            Spree::Api::Dependencies.platform_promotion_batch_destroy_service.constantize
          end
        end
      end
    end
  end
end
