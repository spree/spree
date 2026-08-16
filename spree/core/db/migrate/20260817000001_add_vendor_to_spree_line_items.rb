class AddVendorToSpreeLineItems < ActiveRecord::Migration[8.1]
  # Which seller this line was bought from, snapshotted at the moment it was
  # added. Nil is the operator's own first-party item.
  #
  # Denormalized on purpose rather than walked through the variant on read:
  # the order split partitions on it, vendor order lists and ability scoping
  # filter on it, and once a product can be sold by several sellers the
  # *product* can no longer answer which one a customer actually bought from.
  #
  # Snapshotting also keeps a placed order truthful — a seller's catalog can
  # change hands afterwards, and the line still records who sold it.
  def change
    add_reference :spree_line_items, :vendor, index: true
  end
end
