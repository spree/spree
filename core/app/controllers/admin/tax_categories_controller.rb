class Admin::TaxCategoriesController < Admin::ResourceController

  def index
    if Spree::Config[:show_price_inc_vat] and (TaxCategory.where(:is_default => true).count != 1)
      flash.notice = I18n.t("tax_category_error")
    end
  end
end
