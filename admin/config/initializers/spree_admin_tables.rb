# Default column configurations for Spree Admin Tables
#
# This initializer registers the default tables and their columns.
# Developers can extend these in their own initializers by:
#
# Rails.application.config.after_initialize do
#   Spree.admin.tables.products.add :custom_column, type: :string, default: true
#   Spree.admin.tables.products.remove :sku
#   Spree.admin.tables.products.update :name, position: 5
#   Spree.admin.tables.products.insert_after :name, :vendor, type: :string
# end

Rails.application.config.after_initialize do
  # Register Products table
  Spree.admin.tables.register(:products, model_class: Spree::Product, search_param: :multi_search)

  # Product name with image (custom partial)
  Spree.admin.tables.products.add :name,
                                        label: :name,
                                        type: :custom,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 10,
                                        partial: 'spree/admin/tables/columns/product_name'

  # Product status with help bubble (custom partial)
  Spree.admin.tables.products.add :status,
                                        label: :status,
                                        type: :custom,
                                        filter_type: :status,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 20,
                                        partial: 'spree/admin/tables/columns/product_status',
                                        value_options: [
                                          { value: 'draft', label: 'Draft' },
                                          { value: 'active', label: 'Active' },
                                          { value: 'archived', label: 'Archived' }
                                        ]

  # Inventory display (custom partial)
  Spree.admin.tables.products.add :inventory,
                                        label: :inventory,
                                        type: :custom,
                                        sortable: false,
                                        filterable: false,
                                        default: true,
                                        position: 25,
                                        partial: 'spree/admin/tables/columns/product_inventory'

  Spree.admin.tables.products.add :sku,
                                        label: :sku,
                                        type: :string,
                                        sortable: true,
                                        filterable: true,
                                        default: false,
                                        position: 30,
                                        ransack_attribute: 'master_sku',
                                        method: ->(product) { product.sku }

  Spree.admin.tables.products.add :price,
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

  Spree.admin.tables.products.add :created_at,
                                        label: :created_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: true,
                                        default: false,
                                        position: 50

  Spree.admin.tables.products.add :updated_at,
                                        label: :updated_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: true,
                                        default: false,
                                        position: 60

  # Stock filter (filter-only, not displayed as column)
  Spree.admin.tables.products.add :in_stock,
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
  Spree.admin.tables.products.add :taxons,
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
  Spree.admin.tables.products.add :tags,
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
  Spree.admin.tables.products.add_bulk_action :set_active,
                                                    label: 'admin.bulk_ops.products.title.set_status',
                                                    label_options: { status: :active },
                                                    icon: 'circle-check',
                                                    modal_path: '/admin/products/bulk_modal?kind=set_status&status=active',
                                                    action_path: '/admin/products/bulk_status_update?status=active',
                                                    position: 10,
                                                    condition: -> { can?(:activate, Spree::Product) }

  Spree.admin.tables.products.add_bulk_action :set_draft,
                                                    label: 'admin.bulk_ops.products.title.set_status',
                                                    label_options: { status: :draft },
                                                    icon: 'circle-dotted',
                                                    modal_path: '/admin/products/bulk_modal?kind=set_status&status=draft',
                                                    action_path: '/admin/products/bulk_status_update?status=draft',
                                                    position: 20

  Spree.admin.tables.products.add_bulk_action :set_archived,
                                                    label: 'admin.bulk_ops.products.title.set_status',
                                                    label_options: { status: :archived },
                                                    icon: 'archive',
                                                    modal_path: '/admin/products/bulk_modal?kind=set_status&status=archived',
                                                    action_path: '/admin/products/bulk_status_update?status=archived',
                                                    position: 30

  Spree.admin.tables.products.add_bulk_action :add_to_taxons,
                                                    label: 'admin.bulk_ops.products.title.add_to_taxons',
                                                    icon: 'category-plus',
                                                    modal_path: '/admin/products/bulk_modal?kind=add_to_taxons',
                                                    action_path: '/admin/products/bulk_add_to_taxons',
                                                    position: 40,
                                                    condition: -> { can?(:manage, Spree::Classification) }

  Spree.admin.tables.products.add_bulk_action :remove_from_taxons,
                                                    label: 'admin.bulk_ops.products.title.remove_from_taxons',
                                                    icon: 'category-minus',
                                                    modal_path: '/admin/products/bulk_modal?kind=remove_from_taxons',
                                                    action_path: '/admin/products/bulk_remove_from_taxons',
                                                    position: 50,
                                                    condition: -> { can?(:manage, Spree::Classification) }

  Spree.admin.tables.products.add_bulk_action :add_tags,
                                                    label: 'admin.bulk_ops.products.title.add_tags',
                                                    icon: 'tag-plus',
                                                    modal_path: '/admin/products/bulk_modal?kind=add_tags',
                                                    action_path: '/admin/products/bulk_add_tags',
                                                    position: 60,
                                                    condition: -> { can?(:manage_tags, Spree::Product) }

  Spree.admin.tables.products.add_bulk_action :remove_tags,
                                                    label: 'admin.bulk_ops.products.title.remove_tags',
                                                    icon: 'tag-minus',
                                                    modal_path: '/admin/products/bulk_modal?kind=remove_tags',
                                                    action_path: '/admin/products/bulk_remove_tags',
                                                    position: 70,
                                                    condition: -> { can?(:manage_tags, Spree::Product) }

  # Register Orders table
  Spree.admin.tables.register(:orders, model_class: Spree::Order, search_param: :number_or_email_cont)

  Spree.admin.tables.orders.add :number,
                                      label: :order_number,
                                      type: :link,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 10

  Spree.admin.tables.orders.add :state,
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

  Spree.admin.tables.orders.add :payment_state,
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

  Spree.admin.tables.orders.add :shipment_state,
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

  Spree.admin.tables.orders.add :total,
                                      label: :total,
                                      type: :currency,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 40,
                                      method: ->(order) { order.display_total }

  Spree.admin.tables.orders.add :email,
                                      label: :email,
                                      type: :string,
                                      sortable: true,
                                      filterable: true,
                                      default: false,
                                      position: 45

  Spree.admin.tables.orders.add :completed_at,
                                      label: :completed_at,
                                      type: :datetime,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 50

  Spree.admin.tables.orders.add :created_at,
                                      label: :created_at,
                                      type: :datetime,
                                      sortable: true,
                                      filterable: true,
                                      default: false,
                                      position: 60

  # Register Users table
  Spree.admin.tables.register(:users, model_class: Spree.user_class, search_param: :multi_search, row_actions: false)

  # User name with avatar
  Spree.admin.tables.users.add :name,
                                     label: :name,
                                     type: :custom,
                                     sortable: true,
                                     filterable: false,
                                     default: true,
                                     position: 10,
                                     ransack_attribute: 'first_name',
                                     partial: 'spree/admin/shared/user',
                                     partial_locals: ->(record) { { user: record } }

  # Email marketing status
  Spree.admin.tables.users.add :accepts_email_marketing,
                                     label: :email_marketing,
                                     type: :boolean,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 20,
                                     method: ->(user) { user.accepts_email_marketing? }

  # Location (custom partial with flag)
  Spree.admin.tables.users.add :location,
                                     label: :location,
                                     type: :custom,
                                     filter_type: :autocomplete,
                                     sortable: false,
                                     filterable: true,
                                     default: true,
                                     position: 30,
                                     ransack_attribute: 'addresses_country_name',
                                     operators: %i[eq],
                                     search_url: '/admin/countries/select_options.json',
                                     partial: 'spree/admin/tables/columns/user_location'

  # Number of orders
  Spree.admin.tables.users.add :orders_count,
                                     label: 'admin.num_orders',
                                     type: :number,
                                     sortable: false,
                                     filterable: false,
                                     default: true,
                                     position: 40,
                                     method: ->(user) { user.completed_orders_for_store(Spree::Current.store).count }

  # Amount spent
  Spree.admin.tables.users.add :amount_spent,
                                     label: 'admin.amount_spent',
                                     type: :currency,
                                     sortable: false,
                                     filterable: false,
                                     default: true,
                                     position: 50,
                                     method: ->(user) { user.display_amount_spent_in(Spree::Current.currency) }

  Spree.admin.tables.users.add :created_at,
                                     label: :created_at,
                                     type: :datetime,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 60

  # Filter-only fields (not displayed as columns)
  Spree.admin.tables.users.add :first_name,
                                     label: :first_name,
                                     type: :string,
                                     sortable: true,
                                     filterable: true,
                                     displayable: false,
                                     default: false,
                                     position: 70,
                                     ransack_attribute: 'bill_address_firstname'

  Spree.admin.tables.users.add :last_name,
                                     label: :last_name,
                                     type: :string,
                                     sortable: true,
                                     filterable: true,
                                     displayable: false,
                                     default: false,
                                     position: 80,
                                     ransack_attribute: 'bill_address_lastname'

  Spree.admin.tables.users.add :tags,
                                     label: :tags,
                                     type: :association,
                                     filter_type: :autocomplete,
                                     sortable: false,
                                     filterable: true,
                                     displayable: false,
                                     default: false,
                                     position: 90,
                                     ransack_attribute: 'tags_name',
                                     operators: %i[in],
                                     search_url: '/admin/tags/select_options.json?taggable_type=Spree::User'

  # Users bulk actions
  Spree.admin.tables.users.add_bulk_action :add_tags,
                                                 label: 'admin.bulk_ops.users.title.add_tags',
                                                 icon: 'tag-plus',
                                                 modal_path: '/admin/users/bulk_modal?kind=add_tags',
                                                 action_path: '/admin/users/bulk_add_tags',
                                                 method: :post,
                                                 position: 10,
                                                 condition: -> { can?(:manage_tags, Spree.user_class) }

  Spree.admin.tables.users.add_bulk_action :remove_tags,
                                                 label: 'admin.bulk_ops.users.title.remove_tags',
                                                 icon: 'tag-minus',
                                                 modal_path: '/admin/users/bulk_modal?kind=remove_tags',
                                                 action_path: '/admin/users/bulk_remove_tags',
                                                 method: :post,
                                                 position: 20,
                                                 condition: -> { can?(:manage_tags, Spree.user_class) }

  # Register Promotions table
  Spree.admin.tables.register(:promotions, model_class: Spree::Promotion, search_param: :name_cont)

  Spree.admin.tables.promotions.add :name,
                                          label: :name,
                                          type: :link,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 10

  Spree.admin.tables.promotions.add :code,
                                          label: :code,
                                          type: :custom,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 20,
                                          partial: 'spree/admin/tables/columns/promotion_code'

  Spree.admin.tables.promotions.add :kind,
                                          label: :kind,
                                          type: :custom,
                                          sortable: false,
                                          filterable: false,
                                          default: true,
                                          position: 25,
                                          partial: 'spree/admin/tables/columns/promotion_kind'

  Spree.admin.tables.promotions.add :usage_limit,
                                          label: :usage_limit,
                                          type: :custom,
                                          sortable: false,
                                          filterable: false,
                                          default: true,
                                          position: 30,
                                          partial: 'spree/admin/promotions/usage_limit',
                                          partial_locals: ->(record) { { promotion: record } }

  Spree.admin.tables.promotions.add :status,
                                          label: :status,
                                          type: :custom,
                                          sortable: false,
                                          filterable: false,
                                          default: true,
                                          position: 35,
                                          partial: 'spree/admin/promotions/status',
                                          partial_locals: ->(record) { { promotion: record } }

  Spree.admin.tables.promotions.add :starts_at,
                                          label: :starts_at,
                                          type: :datetime,
                                          sortable: true,
                                          filterable: true,
                                          default: false,
                                          position: 40

  Spree.admin.tables.promotions.add :expires_at,
                                          label: :expires_at,
                                          type: :datetime,
                                          sortable: true,
                                          filterable: true,
                                          default: false,
                                          position: 50

  # Register Posts table
  Spree.admin.tables.register(:posts, model_class: Spree::Post, search_param: :title_cont, row_actions: true)

  Spree.admin.tables.posts.add :title,
                                     label: :title,
                                     type: :link,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 10

  Spree.admin.tables.posts.add :status,
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

  Spree.admin.tables.posts.add :published_at,
                                     label: :published_at,
                                     type: :datetime,
                                     sortable: true,
                                     filterable: true,
                                     default: true,
                                     position: 30

  Spree.admin.tables.posts.add :created_at,
                                     label: :created_at,
                                     type: :datetime,
                                     sortable: true,
                                     filterable: true,
                                     default: false,
                                     position: 40

  # Register Customer Returns table
  Spree.admin.tables.register(:customer_returns, model_class: Spree::CustomerReturn, search_param: :number_cont, row_actions: false, new_resource: false)

  Spree.admin.tables.customer_returns.add :number,
                                                label: :number,
                                                type: :link,
                                                sortable: true,
                                                filterable: true,
                                                default: true,
                                                position: 10

  Spree.admin.tables.customer_returns.add :created_at,
                                                label: :created_at,
                                                type: :datetime,
                                                sortable: true,
                                                filterable: true,
                                                default: true,
                                                position: 20

  Spree.admin.tables.customer_returns.add :customer,
                                                label: :customer,
                                                type: :custom,
                                                sortable: false,
                                                filterable: false,
                                                default: true,
                                                position: 30,
                                                partial: 'spree/admin/orders/customer_summary',
                                                partial_locals: ->(record) { { order: record.order } }

  Spree.admin.tables.customer_returns.add :order,
                                                label: :order,
                                                type: :string,
                                                sortable: false,
                                                filterable: false,
                                                default: true,
                                                position: 40,
                                                method: ->(cr) { cr.order&.number }

  Spree.admin.tables.customer_returns.add :reimbursement_status,
                                                label: :reimbursement_status,
                                                type: :status,
                                                sortable: false,
                                                filterable: false,
                                                default: true,
                                                position: 50,
                                                method: ->(cr) { cr.fully_reimbursed? ? 'reimbursed' : 'incomplete' }

  Spree.admin.tables.customer_returns.add :pre_tax_total,
                                                label: :pre_tax_total,
                                                type: :currency,
                                                sortable: false,
                                                filterable: false,
                                                default: true,
                                                position: 60,
                                                method: ->(cr) { cr.display_pre_tax_total }

  # Register Option Types table
  Spree.admin.tables.register(:option_types, model_class: Spree::OptionType, search_param: :name_cont, row_actions: true)

  Spree.admin.tables.option_types.add :name,
                                            label: :internal_name,
                                            type: :string,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 10,
                                            method: ->(ot) { ot.name }

  Spree.admin.tables.option_types.add :presentation,
                                            label: :presentation,
                                            type: :link,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 20

  Spree.admin.tables.option_types.add :filterable,
                                            label: :filterable,
                                            type: :boolean,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 30

  Spree.admin.tables.option_types.add :option_values_count,
                                            label: :option_values,
                                            type: :number,
                                            sortable: false,
                                            filterable: false,
                                            default: true,
                                            position: 40,
                                            method: ->(ot) { ot.option_values.count }

  Spree.admin.tables.option_types.add :products_count,
                                            label: :products,
                                            type: :number,
                                            sortable: false,
                                            filterable: false,
                                            default: true,
                                            position: 50,
                                            method: ->(ot) { ot.products.count }

  # Register Newsletter Subscribers table
  Spree.admin.tables.register(:newsletter_subscribers, model_class: Spree::NewsletterSubscriber, search_param: :email_cont, row_actions: false, new_resource: false)

  Spree.admin.tables.newsletter_subscribers.add :email,
                                                      label: :email,
                                                      type: :string,
                                                      sortable: true,
                                                      filterable: true,
                                                      default: true,
                                                      position: 10

  Spree.admin.tables.newsletter_subscribers.add :customer,
                                                      label: :customer,
                                                      type: :custom,
                                                      sortable: false,
                                                      filterable: false,
                                                      default: true,
                                                      position: 20,
                                                      partial: 'spree/admin/shared/user',
                                                      partial_locals: ->(record) { { user: record.user } }

  Spree.admin.tables.newsletter_subscribers.add :verified,
                                                      label: :verified,
                                                      type: :boolean,
                                                      sortable: false,
                                                      filterable: true,
                                                      default: true,
                                                      position: 30,
                                                      method: ->(ns) { ns.verified? }

  Spree.admin.tables.newsletter_subscribers.add :verified_at,
                                                      label: :verified_at,
                                                      type: :date,
                                                      sortable: true,
                                                      filterable: true,
                                                      default: true,
                                                      position: 40

  Spree.admin.tables.newsletter_subscribers.add :created_at,
                                                      label: :created_at,
                                                      type: :datetime,
                                                      sortable: true,
                                                      filterable: true,
                                                      default: true,
                                                      position: 50

  # Register Policies table
  Spree.admin.tables.register(:policies, model_class: Spree::Policy, search_param: :name_cont, row_actions: true)

  Spree.admin.tables.policies.add :name,
                                        label: :name,
                                        type: :link,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 10

  Spree.admin.tables.policies.add :slug,
                                        label: :slug,
                                        type: :string,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 20

  Spree.admin.tables.policies.add :filled,
                                        label: :filled,
                                        type: :boolean,
                                        sortable: false,
                                        filterable: false,
                                        default: true,
                                        position: 30,
                                        method: ->(policy) { policy.with_body? }

  Spree.admin.tables.policies.add :updated_at,
                                        label: :updated_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 40

  Spree.admin.tables.policies.add :owner,
                                        label: 'activerecord.attributes.spree/policy.owner',
                                        type: :string,
                                        sortable: false,
                                        filterable: false,
                                        default: true,
                                        position: 50,
                                        method: ->(policy) { policy.owner.name }

  # Register Stock Transfers table
  Spree.admin.tables.register(:stock_transfers, model_class: Spree::StockTransfer, search_param: :number_or_reference_cont)

  Spree.admin.tables.stock_transfers.add :number,
                                               label: :number,
                                               type: :link,
                                               sortable: true,
                                               filterable: true,
                                               default: true,
                                               position: 10

  Spree.admin.tables.stock_transfers.add :reference,
                                               label: :reference,
                                               type: :string,
                                               sortable: true,
                                               filterable: true,
                                               default: true,
                                               position: 20

  Spree.admin.tables.stock_transfers.add :source,
                                               label: :source,
                                               type: :string,
                                               sortable: false,
                                               filterable: false,
                                               default: true,
                                               position: 30,
                                               method: ->(st) { st.source_location&.display_name.presence || Spree.t(:none) }

  Spree.admin.tables.stock_transfers.add :destination,
                                               label: :destination,
                                               type: :string,
                                               sortable: false,
                                               filterable: false,
                                               default: true,
                                               position: 40,
                                               method: ->(st) { st.destination_location.display_name }

  Spree.admin.tables.stock_transfers.add :variants_count,
                                               label: :variants_count,
                                               type: :number,
                                               sortable: false,
                                               filterable: false,
                                               default: true,
                                               position: 50,
                                               method: ->(st) { st.destination_movements.size }

  Spree.admin.tables.stock_transfers.add :created_at,
                                               label: :created_at,
                                               type: :datetime,
                                               sortable: true,
                                               filterable: true,
                                               default: true,
                                               position: 60

  # Register Metafield Definitions table
  Spree.admin.tables.register(:metafield_definitions, model_class: Spree::MetafieldDefinition, search_param: :multi_search, row_actions: true)

  Spree.admin.tables.metafield_definitions.add :key,
                                                     label: :key,
                                                     type: :string,
                                                     sortable: true,
                                                     filterable: true,
                                                     default: true,
                                                     position: 10,
                                                     method: ->(md) { md.full_key }

  Spree.admin.tables.metafield_definitions.add :name,
                                                     label: :name,
                                                     type: :link,
                                                     sortable: true,
                                                     filterable: true,
                                                     default: true,
                                                     position: 20

  Spree.admin.tables.metafield_definitions.add :resource,
                                                     label: :resource,
                                                     type: :string,
                                                     sortable: true,
                                                     filterable: true,
                                                     default: true,
                                                     position: 30,
                                                     ransack_attribute: 'resource_type',
                                                     method: ->(md) { md.resource_type.demodulize.titleize }

  Spree.admin.tables.metafield_definitions.add :type,
                                                     label: :type,
                                                     type: :status,
                                                     sortable: false,
                                                     filterable: false,
                                                     default: true,
                                                     position: 40,
                                                     method: ->(md) { md.metafield_type.demodulize.titleize }

  Spree.admin.tables.metafield_definitions.add :display_on,
                                                     label: :display_on,
                                                     type: :custom,
                                                     sortable: true,
                                                     filterable: true,
                                                     default: true,
                                                     position: 50,
                                                     partial: 'spree/admin/tables/columns/metafield_definition_display_on'

  Spree.admin.tables.metafield_definitions.add :used_in,
                                                     label: 'admin.metafield_definitions.used_in',
                                                     type: :string,
                                                     sortable: false,
                                                     filterable: false,
                                                     default: true,
                                                     position: 60,
                                                     method: ->(md) {
                                                       count = md.metafields.count
                                                       if count.positive?
                                                         "#{count} #{Spree.t(md.resource_type.demodulize.pluralize.to_sym)}"
                                                       else
                                                         Spree.t(:not_available)
                                                       end
                                                     }

  # Register Gift Cards table
  Spree.admin.tables.register(:gift_cards, model_class: Spree::GiftCard, search_param: :code_i_cont, row_actions: false)

  Spree.admin.tables.gift_cards.add :code,
                                          label: :code,
                                          type: :link,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 10,
                                          method: ->(gc) { gc.code.upcase }

  Spree.admin.tables.gift_cards.add :amount,
                                          label: :amount,
                                          type: :currency,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 20,
                                          method: ->(gc) { gc.display_amount }

  Spree.admin.tables.gift_cards.add :used,
                                          label: :used,
                                          type: :currency,
                                          sortable: false,
                                          filterable: false,
                                          default: true,
                                          position: 30,
                                          method: ->(gc) { gc.display_amount_used }

  Spree.admin.tables.gift_cards.add :currency,
                                          label: :currency,
                                          type: :string,
                                          sortable: true,
                                          filterable: false,
                                          default: true,
                                          position: 40,
                                          method: ->(gc) { gc.currency.upcase }

  Spree.admin.tables.gift_cards.add :status,
                                          label: :status,
                                          type: :custom,
                                          sortable: false,
                                          filterable: true,
                                          default: true,
                                          position: 50,
                                          ransack_attribute: 'state',
                                          partial: 'spree/admin/tables/columns/gift_card_status'

  Spree.admin.tables.gift_cards.add :expires_at,
                                          label: :expires_at,
                                          type: :date,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 60

  Spree.admin.tables.gift_cards.add :customer,
                                          label: :customer,
                                          type: :string,
                                          filter_type: :autocomplete,
                                          sortable: false,
                                          filterable: true,
                                          default: true,
                                          position: 70,
                                          ransack_attribute: 'user_id',
                                          operators: %i[eq],
                                          search_url: '/admin/users/select_options.json',
                                          method: ->(gc) { gc.user&.email }
end
