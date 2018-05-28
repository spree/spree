module Spree
  module Adjustable
    class PromotionAccumulator
      attr_reader :adjustments, :sources, :promotions

      # Adds accumulator as an attribute of adjustable to
      # avoid changing number of passed arguments to
      # adjustment#update! and concequential methods
      def self.add_to(adjustable)
        class << adjustable
          attr_accessor :promotion_accumulator
        end

        adjustable.promotion_accumulator = new(adjustable)
      end

      def initialize(adjustable)
        @adjustable = adjustable
        @adjustments = []
        @sources = []
        @promotions = []
        all_adjustments.each { |a| add_adjustment(a) }
      end

      def add_adjustment(adjustment, opts = {})
        return unless adjustment.promotion?
        source = opts[:source] || adjustment.source
        promotion = opts[:promotion] || source.promotion

        add(adjustments, adjustment, adjustment.id)
        add(sources, source, adjustment.source_id)
        add(promotions, promotion, source.promotion_id)
      end

      def promotions_adjustments(promotion_id, adjustments = self.adjustments)
        where(sources, promotion_id: promotion_id).map do |source|
          where(adjustments, source_id: source.id)
        end.flatten
      end

      def promo_total(*args)
        promotions_adjustments(*args).map(&:amount).reduce(0, &:+)
      end

      def total_with_promotion(promotion_id)
        amount + ship_total + promo_total(promotion_id)
      end

      def item_total_with_promotion(promotion_id)
        amount + promo_total(promotion_id, item_adjustments)
      end

      private

      attr_reader :adjustable
      delegate :order, to: :adjustable
      delegate :amount, :ship_total, to: :order

      def all_adjustments
        order.all_adjustments.promotion.includes(source: [:promotion]).where.
          not('adjustable_id = ? AND adjustable_type = ?', adjustable.id, adjustable.class.to_s)
      end

      def add(array, object, id)
        array << object if array.none? { |a| a.id == id }
      end

      def item_adjustments
        adjustments.reject { |a| a.adjustable_type == 'Spree::Shipment' }
      end

      def where(array, opts = {})
        array.select { |a| opts.all? { |k, v| a.respond_to?(k) && a.send(k) == v } }
      end
    end
  end
end
