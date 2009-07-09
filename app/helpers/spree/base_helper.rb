module Spree::BaseHelper

  # this should be cart_path since it returns path only
  # didn't wan't to change until we know what breaks so
  # I named new helpers differently below - WN
  def cart_link
    return new_order_url if session[:order_id].blank?
    return edit_order_url(Order.find_or_create_by_id(session[:order_id]))
  end
  
  def cart_path
    cart_link
  end
  
  
  def link_to_cart(text=t('cart'))
    path = cart_path
    order = Order.find_or_create_by_id(session[:order_id]) unless session[:order_id].blank?
    css_class = ''
    unless order.nil?
      item_count = order.line_items.inject(0) { |kount, line_item| kount + line_item.quantity }
      return "" if current_page?(path)
      text = "#{text}: (#{item_count}) #{order_price(order)}"
      css_class = 'full' if item_count > 0
    end
    link_to text, path, :class => css_class
  end
  
  def order_price(order, options={})
    options.assert_valid_keys(:format_as_currency, :show_vat_text, :show_price_inc_vat)
    options.reverse_merge! :format_as_currency => true, :show_vat_text => true
    
    # overwrite show_vat_text if show_price_inc_vat is false
    options[:show_vat_text] = Spree::Config[:show_price_inc_vat]

    amount =  order.item_total    
    amount += Spree::VatCalculator.calculate_tax(order) if Spree::Config[:show_price_inc_vat]    

    options.delete(:format_as_currency) ? number_to_currency(amount) : amount
  end
  

  def add_product_link(text, product) 
    link_to_remote text, {:url => {:controller => "cart", 
              :action => "add", :id => product}}, 
              {:title => "Add to Cart", 
               :href => url_for( :controller => "cart", 
                          :action => "add", :id => product)} 
  end 
  
  def remove_product_link(text, product) 
    link_to_remote text, {:url => {:controller => "cart", 
                       :action => "remove", 
                       :id => product}}, 
                       {:title => "Remove item", 
                         :href => url_for( :controller => "cart", 
                                     :action => "remove", :id => product)} 
  end 
  
  def todays_short_date
    utc_to_local(Time.now.utc).to_ordinalized_s(:stub)
  end
 
  def yesterdays_short_date
    utc_to_local(Time.now.utc.yesterday).to_ordinalized_s(:stub)
  end  
  

  # human readable list of variant options
  def variant_options(v, allow_back_orders = Spree::Config[:allow_backorders], include_style = true)
    list = v.options_text
    list = include_style ? "<span class =\"out-of-stock\">(" + t("out_of_stock") + ") #{list}</span>" : "#{t("out_of_stock")} #{list}" unless (v.in_stock or allow_back_orders)
    list
  end  
  
  def mini_image(product)
    if product.images.empty?
      image_tag "noimage/mini.jpg"  
    else
      image_tag product.images.first.attachment.url(:mini)  
    end
  end

  def small_image(product)
    if product.images.empty?
      image_tag "noimage/small.jpg"  
    else
      image_tag product.images.first.attachment.url(:small)  
    end
  end

  def product_image(product)
    if product.images.empty?
      image_tag "noimage/product.jpg"  
    else
      image_tag product.images.first.attachment.url(:product)  
    end
  end
  
  def meta_data_tags
    return unless self.respond_to?(:object) && object
    "".tap do |tags|
      if object.respond_to?(:meta_keywords) and object.meta_keywords.present?
        tags << tag('meta', :name => 'keywords', :content => object.meta_keywords) + "\n"
      end
      if object.respond_to?(:meta_description) and object.meta_description.present?
        tags << tag('meta', :name => 'description', :content => object.meta_description) + "\n"
      end
    end
  end

  def stylesheet_tags(paths=stylesheet_paths)
    output = ''
    if !paths.blank?
      paths.each do |path|
        output << stylesheet_link_tag(path)
      end
    end
    return output
  end
  
  def stylesheet_paths
    paths = Spree::Config[:stylesheets]
    if (paths.blank?)
      []
    else
      paths.split(',')
    end
  end

  def logo(image_path=Spree::Config[:logo])
    link_to image_tag(image_path), root_path
  end
end
