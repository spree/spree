module Spree
  class TaxonomiesController < Spree::StoreController
    def show
      @taxonomy = current_store.taxons.where(parent_id: nil).friendly.find(params[:id])

      @taxons = @taxonomy.children.order(name: :asc)
      taxons_grouped = @taxons.group_by { |b| b.name[0].upcase }

      numbers = ('0'..'9').to_a
      alphabet_letters = ('A'..'Z').to_a

      @taxons_grouped_by_letter = begin
        taxons_grouped_by_letter = {}
        alphabet_letters.each do |letter|
          taxons_grouped_by_letter[letter] = taxons_grouped[letter]
        end
        taxons_grouped_by_letter
      end

      @taxons_grouped_by_numbers = taxons_grouped.select { |k, _v| numbers.include?(k) }
      @taxons_grouped_by_other = taxons_grouped.select { |k, _v| alphabet_letters.concat(numbers).exclude?(k) }
    end

    private

    def accurate_title
      @taxonomy.root.seo_title.presence || @taxonomy.root.name
    end
  end
end
