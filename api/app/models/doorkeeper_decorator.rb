module DoorkeeperDecorator
  def self.prepended(base)
    base.table_name.prepend('spree_')
  end
end

Doorkeeper::AccessToken.prepend DoorkeeperDecorator
Doorkeeper::AccessGrant.prepend DoorkeeperDecorator
Doorkeeper::Application.prepend DoorkeeperDecorator
