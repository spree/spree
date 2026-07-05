module Spree
  module Products
    class TouchTaxonsJob < ::Spree::BaseJob
      queue_as Spree.queues.taxons

      def perform(taxon_ids, taxonomy_ids)
        Spree::Taxon.where(id: taxon_ids).update_all(updated_at: Time.current)
        Spree::Taxonomy.where(id: taxonomy_ids).update_all(updated_at: Time.current)
      end
    end
  end
end
