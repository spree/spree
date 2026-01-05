# Default column configurations for Spree Admin Record Lists
#
# This initializer registers the default record lists and their columns.
# Developers can extend these in their own initializers by:
#
# Rails.application.config.after_initialize do
#   Spree.admin.record_lists.products.add :custom_column, type: :string, default: true
#   Spree.admin.record_lists.products.remove :sku
#   Spree.admin.record_lists.products.update :name, position: 5
#   Spree.admin.record_lists.products.insert_after :name, :vendor, type: :string
# end

Rails.application.config.after_initialize do
  # Register Products record list
  Spree.admin.record_lists.register(:products, model_class: Spree::Product, search_param: :multi_search)

  # Product name with image (custom partial)
  Spree.admin.record_lists.products.add :name,
                                        label: :name,
                                        type: :custom,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 10,
                                        partial: 'spree/admin/record_lists/columns/product_name'

  # Product status with help bubble (custom partial)
  Spree.admin.record_lists.products.add :status,
                                        label: :status,
                                        type: :custom,
                                        filter_type: :status,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 20,
                                        partial: 'spree/admin/record_lists/columns/product_status',
                                        value_options: [
                                          { value: 'draft', label: 'Draft' },
                                          { value: 'active', label: 'Active' },
                                          { value: 'archived', label: 'Archived' }
                                        ]

  # Inventory display (custom partial)
  Spree.admin.record_lists.products.add :inventory,
                                        label: :inventory,
                                        type: :custom,
                                        sortable: false,
                                        filterable: false,
                                        default: true,
                                        position: 25,
                                        partial: 'spree/admin/record_lists/columns/product_inventory'

  Spree.admin.record_lists.products.add :sku,
                                        label: :sku,
                                        type: :string,
                                        sortable: true,
                                        filterable: true,
                                        default: false,
                                        position: 30,
                                        ransack_attribute: 'master_sku',
                                        method: ->(product) { product.sku }

  Spree.admin.record_lists.products.add :price,
                                        label: :price,
                                        type: :currency,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 40,
                                        ransack_attribute: 'master_price',
                                        sort_scope_asc: :ascend_by_price,
                                        sort_scope_desc: :descend_by_price,
                                        method: ->(product) { product.price }

  Spree.admin.record_lists.products.add :created_at,
                                        label: :created_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: true,
                                        default: false,
                                        position: 50

  Spree.admin.record_lists.products.add :updated_at,
                                        label: :updated_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: true,
                                        default: false,
                                        position: 60

  # Stock filter (filter-only, not displayed as column)
  Spree.admin.record_lists.products.add :in_stock,
                                        label: 'In Stock',
                                        type: :boolean,
                                        filter_type: :boolean,
                                        sortable: false,
                                        filterable: true,
                                        displayable: false,
                                        default: false,
                                        position: 70,
                                        ransack_attribute: 'in_stock_items'

  # Taxons - displayed as comma-separated list, filtered via autocomplete
  Spree.admin.record_lists.products.add :taxons,
                                        label: :taxons,
                                        type: :association,
                                        filter_type: :autocomplete,
                                        sortable: false,
                                        filterable: true,
                                        default: false,
                                        position: 80,
                                        ransack_attribute: 'taxons_id',
                                        operators: %i[in],
                                        search_url: '/admin/taxons/select_options.json',
                                        method: ->(product) { product.taxons.map(&:pretty_name).join(', ') }

  # Tags - displayed as comma-separated list, filtered via autocomplete
  Spree.admin.record_lists.products.add :tags,
                                        label: :tags,
                                        type: :association,
                                        filter_type: :autocomplete,
                                        sortable: false,
                                        filterable: true,
                                        default: false,
                                        position: 85,
                                        ransack_attribute: 'tags_name',
                                        operators: %i[in],
                                        search_url: '/admin/tags/select_options.json?taggable_type=Spree::Product',
                                        method: ->(product) { product.tag_list.join(', ') }

  # Products bulk actions
  Spree.admin.record_lists.products.add_bulk_action :set_active,
                                                    label: 'admin.bulk_ops.products.title.set_status',
                                                    label_options: { status: :active },
                                                    icon: 'circle-check',
                                                    modal_path: '/admin/products/bulk_modal?kind=set_status&status=active',
                                                    action_path: '/admin/products/bulk_status_update?status=active',
                                                    position: 10,
                                                    condition: -> { can?(:activate, Spree::Product) }

  Spree.admin.record_lists.products.add_bulk_action :set_draft,
                                                    label: 'admin.bulk_ops.products.title.set_status',
                                                    label_options: { status: :draft },
                                                    icon: 'circle-dotted',
                                                    modal_path: '/admin/products/bulk_modal?kind=set_status&status=draft',
                                                    action_path: '/admin/products/bulk_status_update?status=draft',
                                                    position: 20

  Spree.admin.record_lists.products.add_bulk_action :set_archived,
                                                    label: 'admin.bulk_ops.products.title.set_status',
                                                    label_options: { status: :archived },
                                                    icon: 'archive',
                                                    modal_path: '/admin/products/bulk_modal?kind=set_status&status=archived',
                                                    action_path: '/admin/products/bulk_status_update?status=archived',
                                                    position: 30

  Spree.admin.record_lists.products.add_bulk_action :add_to_taxons,
                                                    label: 'admin.bulk_ops.products.title.add_to_taxons',
                                                    icon: 'category-plus',
                                                    modal_path: '/admin/products/bulk_modal?kind=add_to_taxons',
                                                    action_path: '/admin/products/bulk_add_to_taxons',
                                                    position: 40,
                                                    condition: -> { can?(:manage, Spree::Classification) }

  Spree.admin.record_lists.products.add_bulk_action :remove_from_taxons,
                                                    label: 'admin.bulk_ops.products.title.remove_from_taxons',
                                                    icon: 'category-minus',
                                                    modal_path: '/admin/products/bulk_modal?kind=remove_from_taxons',
                                                    action_path: '/admin/products/bulk_remove_from_taxons',
                                                    position: 50,
                                                    condition: -> { can?(:manage, Spree::Classification) }

  Spree.admin.record_lists.products.add_bulk_action :add_tags,
                                                    label: 'admin.bulk_ops.products.title.add_tags',
                                                    icon: 'tag-plus',
                                                    modal_path: '/admin/products/bulk_modal?kind=add_tags',
                                                    action_path: '/admin/products/bulk_add_tags',
                                                    position: 60,
                                                    condition: -> { can?(:manage_tags, Spree::Product) }

  Spree.admin.record_lists.products.add_bulk_action :remove_tags,
                                                    label: 'admin.bulk_ops.products.title.remove_tags',
                                                    icon: 'tag-minus',
                                                    modal_path: '/admin/products/bulk_modal?kind=remove_tags',
                                                    action_path: '/admin/products/bulk_remove_tags',
                                                    position: 70,
                                                    condition: -> { can?(:manage_tags, Spree::Product) }

  # Register Orders record list
  Spree.admin.record_lists.register(:orders, model_class: Spree::Order, search_param: :number_or_email_cont)

  Spree.admin.record_lists.orders.add :number,
                                      label: :order_number,
                                      type: :link,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 10

  Spree.admin.record_lists.orders.add :state,
                                      label: :state,
                                      type: :status,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 20,
                                      value_options: [
                                        { value: 'cart', label: 'Cart' },
                                        { value: 'address', label: 'Address' },
                                        { value: 'delivery', label: 'Delivery' },
                                        { value: 'payment', label: 'Payment' },
                                        { value: 'confirm', label: 'Confirm' },
                                        { value: 'complete', label: 'Complete' },
                                        { value: 'canceled', label: 'Canceled' }
                                      ]

  Spree.admin.record_lists.orders.add :payment_state,
                                      label: :payment_state,
                                      type: :status,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 30,
                                      value_options: [
                                        { value: 'balance_due', label: 'Balance Due' },
                                        { value: 'credit_owed', label: 'Credit Owed' },
                                        { value: 'failed', label: 'Failed' },
                                        { value: 'paid', label: 'Paid' },
                                        { value: 'void', label: 'Void' }
                                      ]

  Spree.admin.record_lists.orders.add :shipment_state,
                                      label: :shipment_state,
                                      type: :status,
                                      sortable: true,
                                      filterable: true,
                                      default: false,
                                      position: 35,
                                      value_options: [
                                        { value: 'backorder', label: 'Backorder' },
                                        { value: 'canceled', label: 'Canceled' },
                                        { value: 'partial', label: 'Partial' },
                                        { value: 'pending', label: 'Pending' },
                                        { value: 'ready', label: 'Ready' },
                                        { value: 'shipped', label: 'Shipped' }
                                      ]

  Spree.admin.record_lists.orders.add :total,
                                      label: :total,
                                      type: :currency,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 40,
                                      method: ->(order) { order.display_total }

  Spree.admin.record_lists.orders.add :email,
                                      label: :email,
                                      type: :string,
                                      sortable: true,
                                      filterable: true,
                                      default: false,
                                      position: 45

  Spree.admin.record_lists.orders.add :completed_at,
                                      label: :completed_at,
                                      type: :datetime,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 50

  Spree.admin.record_lists.orders.add :created_at,
                                      label: :created_at,
                                      type: :datetime,
                                      sortable: true,
                                      filterable: true,
                                      default: false,
                                      position: 60

  # Register Users record list
  Spree.admin.record_lists.register(:users, model_class: Spree.user_class, search_param: :email_cont)

  Spree.admin.record_lists.users.add :email,
                                     label: :email,
                                     type: :link,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 10

  Spree.admin.record_lists.users.add :first_name,
                                     label: :first_name,
                                     type: :string,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 20,
                                     ransack_attribute: 'bill_address_firstname'

  Spree.admin.record_lists.users.add :last_name,
                                     label: :last_name,
                                     type: :string,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 30,
                                     ransack_attribute: 'bill_address_lastname'

  Spree.admin.record_lists.users.add :created_at,
                                     label: :created_at,
                                     type: :datetime,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 40

  # Users bulk actions
  Spree.admin.record_lists.users.add_bulk_action :add_tags,
                                                 label: 'admin.bulk_ops.users.title.add_tags',
                                                 icon: 'tag-plus',
                                                 modal_path: '/admin/users/bulk_modal?kind=add_tags',
                                                 action_path: '/admin/users/bulk_add_tags',
                                                 method: :post,
                                                 position: 10,
                                                 condition: -> { can?(:manage_tags, Spree.user_class) }

  Spree.admin.record_lists.users.add_bulk_action :remove_tags,
                                                 label: 'admin.bulk_ops.users.title.remove_tags',
                                                 icon: 'tag-minus',
                                                 modal_path: '/admin/users/bulk_modal?kind=remove_tags',
                                                 action_path: '/admin/users/bulk_remove_tags',
                                                 method: :post,
                                                 position: 20,
                                                 condition: -> { can?(:manage_tags, Spree.user_class) }

  # Register Promotions record list
  Spree.admin.record_lists.register(:promotions, model_class: Spree::Promotion, search_param: :name_cont)

  Spree.admin.record_lists.promotions.add :name,
                                          label: :name,
                                          type: :link,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 10

  Spree.admin.record_lists.promotions.add :code,
                                          label: :code,
                                          type: :string,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 20

  Spree.admin.record_lists.promotions.add :starts_at,
                                          label: :starts_at,
                                          type: :datetime,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 30

  Spree.admin.record_lists.promotions.add :expires_at,
                                          label: :expires_at,
                                          type: :datetime,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 40

  # Register Posts record list
  Spree.admin.record_lists.register(:posts, model_class: Spree::Post, search_param: :title_cont)

  Spree.admin.record_lists.posts.add :title,
                                     label: :title,
                                     type: :link,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 10

  Spree.admin.record_lists.posts.add :status,
                                     label: :status,
                                     type: :status,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 20,
                                     value_options: [
                                       { value: 'draft', label: 'Draft' },
                                       { value: 'published', label: 'Published' }
                                     ]

  Spree.admin.record_lists.posts.add :published_at,
                                     label: :published_at,
                                     type: :datetime,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 30

  Spree.admin.record_lists.posts.add :created_at,
                                     label: :created_at,
                                     type: :datetime,
                                     sortable: true,
                                     filterable: true,
                                     default: false,
                                     position: 40
end
