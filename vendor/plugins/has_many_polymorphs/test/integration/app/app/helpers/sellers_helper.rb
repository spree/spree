module SellersHelper

  def display_address(seller)
    logger.info "Seller Data ===================="
    logger.info seller.inspect
    logger.info "Seller responds to address " + seller.respond_to?("address").to_s
    logger.info "Seller responds to address= " + seller.respond_to?("address=").to_s
    # logger.info seller.methods.sort.inspect
    logger.info "User Data ===================="
    logger.info seller.user.inspect
    logger.info "User responds to address " + seller.user.respond_to?("address").to_s
    logger.info "User responds to address= " + seller.user.respond_to?("address=").to_s
    # logger.info seller.user.methods.sort.inspect
    display_address = Array.new
    if seller.address
      display_address << seller.address.city if seller.address.city
      display_address << seller.address.state.abbreviation if seller.address.state && seller.address.state.abbreviation
      display_address << seller.address.zip_postal_code if seller.address.zip_postal_code
    end
    
    unless display_address.empty?
      "Location: " + display_address.join(", ")
    else
      "Location: unknown"
    end
  end
  
end