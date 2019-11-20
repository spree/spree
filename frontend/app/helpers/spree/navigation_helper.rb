module Spree
  module NavigationHelper
    def categories_data
      [
        {
          name: :women,
          url: nested_taxons_path('women'),
          subcategories: [
            { dresses: nested_taxons_path('women/dresses') },
            { shirts_and_blouses: nested_taxons_path('women/shirts-and-blouses') },
            { t_shirts_and_tops: nested_taxons_path('women/tops-and-t-shirts') },
            { sweaters: nested_taxons_path('women/sweaters') },
            { skirts: nested_taxons_path('women/skirts') },
            { jackets_and_coats: nested_taxons_path('women/jackets-and-coats') }
          ]
        },
        {
          name: :men,
          url: nested_taxons_path('men'),
          subcategories: [
            { shirts: nested_taxons_path('men/shirts') },
            { t_shirts: nested_taxons_path('men/t-shirts') },
            { sweaters: nested_taxons_path('men/sweaters') },
            { jackets_and_coats: nested_taxons_path('men/jackets-and-coats') }
          ]
        },
        {
          name: :sportswear,
          url: nested_taxons_path('sportswear'),
          subcategories: [
            { tops: nested_taxons_path('sportswear/tops') },
            { pants: nested_taxons_path('sportswear/pants') },
            { sweatshirts: nested_taxons_path('sportswear/sweatshirts') }
          ]
        }
      ]
    end
  end
end
