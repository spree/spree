module Spree
  class MegaNavPresenter
    ColumnPresenter = Struct.new(:title, :links, :view_all_linkable, keyword_init: true)

    def initialize(mega_nav)
      @mega_nav = mega_nav
    end

    def main_link
      @main_link ||=
        if mega_nav.is_a?(Spree::PageBlocks::MegaNavWithSubcategories)
          to_link(mega_nav.taxon)
        else
          mega_nav.links.first
        end
    end

    def columns
      @columns ||=
        if mega_nav.is_a?(Spree::PageBlocks::MegaNavWithSubcategories)
          subcategories = mega_nav.taxon&.self_and_descendants || []
          main_subcategories = subcategories.find_all { |c| c.parent_id == mega_nav.taxon.id }.sort_by(&:position)

          main_subcategories.first(max_columns).map do |child_category|
            links = subcategories.find_all { |c| c.parent_id == child_category.id }.sort_by(&:position).map(&method(:to_link))
            ColumnPresenter.new(title: child_category.name, links: links, view_all_linkable: child_category)
          end.compact_blank
        elsif mega_nav.is_a?(Spree::PageBlocks::MegaNav)
          [ColumnPresenter.new(title: main_link.label, links: mega_nav.links.drop(1), view_all_linkable: main_link.linkable)]
        else
          []
        end
    end

    private

    attr_reader :mega_nav

    def to_link(object)
      if object.is_a?(Spree::Taxon)
        Spree::PageLink.new(
          linkable: object,
          label: object.name,
          open_in_new_tab: false
        )
      else
        object
      end
    end

    def max_columns
      @max_columns ||= mega_nav.featured_taxon.present? ? 3 : 4
    end
  end
end
