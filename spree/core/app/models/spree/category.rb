module Spree
  # Public API name for Taxon, used by the admin dashboard. Unlike a legacy
  # +Spree::Taxon+, a Category does not require a +Spree::Taxonomy+ — it is
  # owned directly via +store_id+, so a parentless category is a genuine
  # top-level node. (Legacy taxonomy-backed taxons are unaffected.) Will become
  # the base class in 6.0 when +Spree::Taxonomy+ is dropped and +spree_taxons+
  # is renamed to +spree_categories+.
  class Category < Taxon
    default_scope { manual }

    # A category is owned directly via +store_id+ and never needs a taxonomy.
    def requires_taxonomy?
      false
    end
  end
end
