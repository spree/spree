module Spree
  module PromotionBatches
    class BatchCodeGenerator
      class << self
        def build(batch_id, options)
          promotion_batch = Spree::PromotionBatch.find(batch_id)
          codes = codes(promotion_batch)
          code_generator = code_generator(options)

          loop do
            candidate = generate_code(code_generator)
            break candidate if candidate_valid?(candidate, codes)
          end
        end

        private

        def codes(promotion_batch)
          promotion_batch.promotions.pluck :code
        end

        def code_generator(options)
          Spree::Promotions::CodeGenerator.new(
            content: options[:content],
            affix: options[:affix],
            deny_list: options[:deny_list],
            random_part_bytes: options[:random_part_bytes]
          )
        end

        def generate_code(generator)
          generator.build
        end

        def candidate_valid?(candidate, codes)
          codes.exclude?(candidate)
        end
      end
    end
  end
end
