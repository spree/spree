module Spree
  module StaticImagesHelper
    def main_banner
      if Rails.application.assets.find_asset('homepage/main_banner.jpg')
        asset_path('homepage/main_banner.jpg')
      else
        asset_path('homepage/temporary_renamed_main_banner.jpg')
      end
    end

    def category_banner_upper
      if Rails.application.assets.find_asset('homepage/category_banner_upper.jpg')
        asset_path('homepage/category_banner_upper.jpg')
      else
        asset_path('homepage/temporary_renamed_category_banner_upper.jpg')
      end
    end

    def category_banner_lower
      if Rails.application.assets.find_asset('homepage/category_banner_lower.jpg')
        asset_path('homepage/category_banner_lower.jpg')
      else
        asset_path('homepage/temporary_renamed_category_banner_lower.jpg')
      end
    end

    def big_category_banner
      if Rails.application.assets.find_asset('homepage/big_category_banner.jpg')
        asset_path('homepage/big_category_banner.jpg')
      else
        asset_path('homepage/temporary_renamed_big_category_banner.jpg')
      end
    end

    def promo_banner_left
      if Rails.application.assets.find_asset('homepage/promo_banner_left.jpg')
        asset_path('homepage/promo_banner_left.jpg')
      else
        asset_path('homepage/temporary_renamed_promo_banner_left.jpg')
      end
    end

    def promo_banner_right
      if Rails.application.assets.find_asset('homepage/promo_banner_right.jpg')
        asset_path('homepage/promo_banner_right.jpg')
      else
        asset_path('homepage/temporary_renamed_promo_banner_right.jpg')
      end
    end

    def homepage_products
      if Rails.application.assets.find_asset('homepage/products.jpg')
        asset_path('homepage/products.jpg')
      else
        asset_path('homepage/temporary_renamed_products.jpg')
      end
    end
  end
end