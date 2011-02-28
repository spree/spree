Order.class_eval do
  token_resource

  after_save :save_user_addresses, :if => '@save_addresses_for_next_order'
  attr_accessor :save_addresses_for_next_order
  attr_accessible :save_addresses_for_next_order

  def save_user_addresses
    return unless save_addresses_for_next_order == "1"
    return unless self.user

    self.user.bill_address ||= Address.new
    self.user.ship_address ||= Address.new

    except_args = ['id', 'created_at', 'updated_at']
    self.user.bill_address.update_attributes \
      self.bill_address.attributes.except(*except_args)
    self.user.ship_address.update_attributes \
      self.ship_address.attributes.except(*except_args)

    self.user.save unless self.user.bill_address_id && self.user.ship_address_id

    # don't run on next call
    @save_addresses_for_next_order = nil
  end

  def load_user_addresses
    return unless self.user

    except_args = ['id', 'created_at', 'updated_at']
    if self.user.bill_address && self.user.bill_address.valid?
      self.bill_address ||=
        Address.new self.user.bill_address.attributes.except(*except_args)
    end
    if self.user.ship_address && self.user.ship_address.valid?
      self.ship_address ||=
        Address.new self.user.ship_address.attributes.except(*except_args)
    end
  end

  # Associates the specified user with the order and destroys any previous association with guest user if
  # necessary.
  def associate_user!(user)
    self.user = user
    self.email = user.email
    load_user_addresses
    # disable validations since this can cause issues when associating an incomplete address during the address step
    save(:validate => false)
  end

  # TODO: validate the format of the email as well (but we can't rely on authlogic anymore to help with validation)
  validates_presence_of :email, :if => :require_email
  validates_format_of :email, :with => /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i, :if => :require_email
end
