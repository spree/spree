class AddSellerAndDeliveryProfileToSpreeVariants < ActiveRecord::Migration[8.1]
  # Which seller sells this variant, and how they ship it.
  #
  # The seller sits on the variant rather than only on the product because
  # several sellers may sell the same item: one product page carries the
  # marketplace's own new unit beside a seller's refurbished one, and only the
  # variant can say which of them a customer chose. Nil is first-party.
  #
  # The delivery profile follows Spree::Variant#tax_category — nil defers to
  # the product. Without it two sellers sharing a product would also share
  # whichever shipping configuration resolved first, packing and pricing one
  # seller's goods with another's.
  def change
    add_reference :spree_variants, :seller, index: true
    add_reference :spree_variants, :delivery_profile, index: true
  end
end
