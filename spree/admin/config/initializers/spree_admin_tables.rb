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
                                        sortable: false,
                                        filterable: true,
                                        default: false,
                                        position: 30,
                                        ransack_attribute: 'master_sku',
                                        method: ->(product) { product.sku }

  Spree.admin.tables.products.add :price,
                                        label: :price,
                                        type: :money,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 40,
                                        ransack_attribute: 'master_price',
                                        sort_scope_asc: :ascend_by_price,
                                        sort_scope_desc: :descend_by_price,
                                        method: ->(product) { product.price_in(Spree::Current.currency) }

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
                                        ransack_attribute: 'in_stock'

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
                                        search_url: ->(view_context) { view_context.spree.admin_taxons_select_options_path(format: :json) },
                                        method: ->(product) { product.taxons.pluck(:pretty_name).to_sentence if product.classification_count.positive? }

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
                                        search_url: ->(view_context) { view_context.spree.admin_tags_select_options_path(format: :json, taggable_type: 'Spree::Product') },
                                        method: ->(product) { product.tag_list.to_sentence }

  # Products bulk actions
  Spree.admin.tables.products.add_bulk_action :set_active,
                                                    label: 'admin.bulk_ops.products.title.set_active',
                                                    icon: 'circle-check',
                                                    action_path: ->(view_context) { view_context.spree.bulk_status_update_admin_products_path(status: 'active') },
                                                    body: 'admin.bulk_ops.products.body.set_active',
                                                    position: 10,
                                                    condition: -> { can?(:activate, Spree::Product) }

  Spree.admin.tables.products.add_bulk_action :set_draft,
                                                    label: 'admin.bulk_ops.products.title.set_draft',
                                                    icon: 'circle-dotted',
                                                    action_path: ->(view_context) { view_context.spree.bulk_status_update_admin_products_path(status: 'draft') },
                                                    body: 'admin.bulk_ops.products.body.set_draft',
                                                    position: 20

  Spree.admin.tables.products.add_bulk_action :set_archived,
                                                    label: 'admin.bulk_ops.products.title.set_archived',
                                                    icon: 'archive',
                                                    action_path: ->(view_context) { view_context.spree.bulk_status_update_admin_products_path(status: 'archived') },
                                                    body: 'admin.bulk_ops.products.body.set_archived',
                                                    position: 30

  Spree.admin.tables.products.add_bulk_action :add_to_taxons,
                                                    label: 'admin.bulk_ops.products.title.add_to_taxons',
                                                    icon: 'category-plus',
                                                    action_path: ->(view_context) { view_context.spree.bulk_add_to_taxons_admin_products_path },
                                                    body: 'admin.bulk_ops.products.body.add_to_taxons',
                                                    form_partial: 'spree/admin/bulk_operations/forms/taxon_picker',
                                                    position: 40,
                                                    condition: -> { can?(:manage, Spree::Classification) }

  Spree.admin.tables.products.add_bulk_action :remove_from_taxons,
                                                    label: 'admin.bulk_ops.products.title.remove_from_taxons',
                                                    icon: 'category-minus',
                                                    action_path: ->(view_context) { view_context.spree.bulk_remove_from_taxons_admin_products_path },
                                                    body: 'admin.bulk_ops.products.body.remove_from_taxons',
                                                    form_partial: 'spree/admin/bulk_operations/forms/taxon_picker',
                                                    position: 50,
                                                    condition: -> { can?(:manage, Spree::Classification) }

  Spree.admin.tables.products.add_bulk_action :add_tags,
                                                    label: 'admin.bulk_ops.products.title.add_tags',
                                                    icon: 'tag-plus',
                                                    action_path: ->(view_context) { view_context.spree.bulk_add_tags_admin_products_path },
                                                    body: 'admin.bulk_ops.products.body.add_tags',
                                                    form_partial: 'spree/admin/bulk_operations/forms/tag_picker',
                                                    form_partial_locals: { allow_create: true },
                                                    position: 60,
                                                    condition: -> { can?(:manage_tags, Spree::Product) }

  Spree.admin.tables.products.add_bulk_action :remove_tags,
                                                    label: 'admin.bulk_ops.products.title.remove_tags',
                                                    icon: 'tag-minus',
                                                    action_path: ->(view_context) { view_context.spree.bulk_remove_tags_admin_products_path },
                                                    body: 'admin.bulk_ops.products.body.remove_tags',
                                                    form_partial: 'spree/admin/bulk_operations/forms/tag_picker',
                                                    form_partial_locals: { allow_create: false },
                                                    position: 70,
                                                    condition: -> { can?(:manage_tags, Spree::Product) }

  # Register Orders table
  Spree.admin.tables.register(:orders, model_class: Spree::Order, search_param: :multi_search, date_range_param: :completed_at)

  Spree.admin.tables.orders.add :number,
                                      label: :number,
                                      type: :link,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 10

  Spree.admin.tables.orders.add :completed_at,
                                      label: :completed_at,
                                      type: :datetime,
                                      sortable: true,
                                      filterable: false,
                                      default: true,
                                      position: 20

  Spree.admin.tables.orders.add :customer,
                                      label: :customer,
                                      type: :custom,
                                      sortable: false,
                                      filterable: false,
                                      default: true,
                                      position: 30,
                                      partial: 'spree/admin/orders/customer_summary',
                                      partial_locals: ->(record) { { order: record } }

  Spree.admin.tables.orders.add :stock_location,
                                      label: :package_from,
                                      type: :custom,
                                      sortable: false,
                                      filterable: false,
                                      default: true,
                                      position: 40,
                                      partial: 'spree/admin/tables/columns/order_stock_locations'

  Spree.admin.tables.orders.add :payment_state,
                                      label: :payment_state,
                                      type: :custom,
                                      filter_type: :select,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 50,
                                      partial: 'spree/admin/tables/columns/order_payment_state',
                                      operators: %i[eq not_eq in not_in],
                                      value_options: -> { Spree::Order::PAYMENT_STATES.map { |s| { value: s, label: I18n.t("spree.payment_states.#{s}", default: s.humanize) } } }

  Spree.admin.tables.orders.add :shipment_state,
                                      label: :shipment_state,
                                      type: :custom,
                                      filter_type: :select,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 60,
                                      partial: 'spree/admin/tables/columns/order_shipment_state',
                                      operators: %i[eq not_eq in not_in],
                                      value_options: -> { Spree::Order::SHIPMENT_STATES.map { |s| { value: s, label: I18n.t("spree.shipment_states.#{s}", default: s.humanize) } } }

  Spree.admin.tables.orders.add :item_count,
                                      label: :item_count,
                                      type: :number,
                                      sortable: true,
                                      filterable: false,
                                      default: true,
                                      position: 70,
                                      align: :right,
                                      method: ->(order) { pluralize(order.item_count, 'item') }

  Spree.admin.tables.orders.add :total,
                                      label: :total,
                                      type: :money,
                                      sortable: true,
                                      filterable: true,
                                      default: true,
                                      position: 80,
                                      align: :right,
                                      method: ->(order) { order.display_total }

  Spree.admin.tables.orders.add :state,
                                      label: :state,
                                      type: :status,
                                      filter_type: :select,
                                      sortable: true,
                                      filterable: true,
                                      default: false,
                                      position: 90,
                                      operators: %i[eq not_eq in not_in],
                                      value_options: -> { Spree::Order.state_machine(:state).states.map { |s| { value: s.name.to_s, label: s.name.to_s.humanize } } }

  Spree.admin.tables.orders.add :email,
                                      label: :email,
                                      type: :string,
                                      sortable: true,
                                      filterable: true,
                                      default: false,
                                      position: 100

  Spree.admin.tables.orders.add :created_at,
                                      label: :created_at,
                                      type: :datetime,
                                      sortable: true,
                                      filterable: false,
                                      default: false,
                                      position: 110

  Spree.admin.tables.orders.add :updated_at,
                                      label: :updated_at,
                                      type: :datetime,
                                      sortable: true,
                                      filterable: false,
                                      default: false,
                                      position: 115

  # Filter-only fields (not displayed as columns)
  Spree.admin.tables.orders.add :first_name,
                                      label: :first_name,
                                      type: :string,
                                      sortable: false,
                                      filterable: true,
                                      displayable: false,
                                      default: false,
                                      position: 120,
                                      ransack_attribute: 'bill_address_firstname_i'

  Spree.admin.tables.orders.add :last_name,
                                      label: :last_name,
                                      type: :string,
                                      sortable: false,
                                      filterable: true,
                                      displayable: false,
                                      default: false,
                                      position: 130,
                                      ransack_attribute: 'bill_address_lastname'

  Spree.admin.tables.orders.add :sku,
                                      label: :sku,
                                      type: :string,
                                      sortable: false,
                                      filterable: true,
                                      displayable: false,
                                      default: false,
                                      position: 140,
                                      ransack_attribute: 'line_items_variant_sku'

  Spree.admin.tables.orders.add :promotion,
                                      label: :promotion,
                                      type: :association,
                                      filter_type: :autocomplete,
                                      sortable: false,
                                      filterable: true,
                                      displayable: false,
                                      default: false,
                                      position: 150,
                                      ransack_attribute: 'promotions_id',
                                      operators: %i[in],
                                      search_url: ->(view_context) { view_context.spree.select_options_admin_promotions_path(format: :json) }

  # Register Checkouts table (draft orders)
  Spree.admin.tables.register(:checkouts, model_class: Spree::Order, search_param: :multi_search, date_range_param: :created_at, new_resource: false)

  Spree.admin.tables.checkouts.add :number,
                                        label: :number,
                                        type: :link,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 10

  Spree.admin.tables.checkouts.add :created_at,
                                        label: :created_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: false,
                                        default: true,
                                        position: 20

  Spree.admin.tables.checkouts.add :customer,
                                        label: :customer,
                                        type: :custom,
                                        sortable: false,
                                        filterable: false,
                                        default: true,
                                        position: 30,
                                        partial: 'spree/admin/orders/customer_summary',
                                        partial_locals: ->(record) { { order: record } }

  Spree.admin.tables.checkouts.add :state,
                                        label: :state,
                                        type: :status,
                                        filter_type: :select,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 40,
                                        operators: %i[eq not_eq in not_in],
                                        value_options: -> { Spree::Order.state_machine(:state).states.map { |s| { value: s.name.to_s, label: s.name.to_s.humanize } } }

  Spree.admin.tables.checkouts.add :item_count,
                                        label: :item_count,
                                        type: :number,
                                        sortable: true,
                                        filterable: false,
                                        default: true,
                                        position: 50,
                                        align: :right,
                                        method: ->(order) { pluralize(order.item_count, 'item') }

  Spree.admin.tables.checkouts.add :total,
                                        label: :total,
                                        type: :money,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 60,
                                        align: :right,
                                        method: ->(order) { order.display_total }

  Spree.admin.tables.checkouts.add :email,
                                        label: :email,
                                        type: :string,
                                        sortable: true,
                                        filterable: true,
                                        default: false,
                                        position: 70

  Spree.admin.tables.checkouts.add :updated_at,
                                        label: :updated_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: false,
                                        default: false,
                                        position: 80

  # Register Users table
  Spree.admin.tables.register(:users, model_class: Spree.user_class, search_param: :multi_search, row_actions: false, link_to_action: :show)

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
                                     search_url: ->(view_context) { view_context.spree.admin_countries_select_options_path(format: :json) },
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
                                     type: :money,
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

  Spree.admin.tables.users.add :updated_at,
                                     label: :updated_at,
                                     type: :datetime,
                                     sortable: true,
                                     filterable: true,
                                     default: false,
                                     position: 65

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
                                     search_url: ->(view_context) { view_context.spree.admin_tags_select_options_path(format: :json, taggable_type: 'Spree::User') }

  # Users bulk actions
  Spree.admin.tables.users.add_bulk_action :add_tags,
                                                 label: 'admin.bulk_ops.users.title.add_tags',
                                                 icon: 'tag-plus',
                                                 action_path: ->(view_context) { view_context.spree.bulk_add_tags_admin_users_path },
                                                 body: 'admin.bulk_ops.users.body.add_tags',
                                                 form_partial: 'spree/admin/bulk_operations/forms/tag_picker',
                                                 form_partial_locals: { allow_create: true },
                                                 method: :post,
                                                 position: 10,
                                                 condition: -> { can?(:manage_tags, Spree.user_class) }

  Spree.admin.tables.users.add_bulk_action :remove_tags,
                                                 label: 'admin.bulk_ops.users.title.remove_tags',
                                                 icon: 'tag-minus',
                                                 action_path: ->(view_context) { view_context.spree.bulk_remove_tags_admin_users_path },
                                                 body: 'admin.bulk_ops.users.body.remove_tags',
                                                 form_partial: 'spree/admin/bulk_operations/forms/tag_picker',
                                                 form_partial_locals: { allow_create: false },
                                                 method: :post,
                                                 position: 20,
                                                 condition: -> { can?(:manage_tags, Spree.user_class) }

  # Register Promotions table
  Spree.admin.tables.register(:promotions, model_class: Spree::Promotion, search_param: :name_cont, link_to_action: :show)

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

  Spree.admin.tables.promotions.add :created_at,
                                          label: :created_at,
                                          type: :datetime,
                                          sortable: true,
                                          filterable: true,
                                          default: false,
                                          position: 60

  Spree.admin.tables.promotions.add :updated_at,
                                          label: :updated_at,
                                          type: :datetime,
                                          sortable: true,
                                          filterable: true,
                                          default: false,
                                          position: 70

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
                                                type: :money,
                                                sortable: false,
                                                filterable: false,
                                                default: true,
                                                position: 60,
                                                method: ->(cr) { cr.display_pre_tax_total }

  Spree.admin.tables.customer_returns.add :updated_at,
                                                label: :updated_at,
                                                type: :datetime,
                                                sortable: true,
                                                filterable: true,
                                                default: false,
                                                position: 70

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

  Spree.admin.tables.option_types.add :created_at,
                                            label: :created_at,
                                            type: :datetime,
                                            sortable: true,
                                            filterable: true,
                                            default: false,
                                            position: 60

  Spree.admin.tables.option_types.add :updated_at,
                                            label: :updated_at,
                                            type: :datetime,
                                            sortable: true,
                                            filterable: true,
                                            default: false,
                                            position: 70

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
                                                      partial: 'spree/admin/tables/columns/newsletter_subscriber_customer'

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

  Spree.admin.tables.newsletter_subscribers.add :updated_at,
                                                      label: :updated_at,
                                                      type: :datetime,
                                                      sortable: true,
                                                      filterable: true,
                                                      default: false,
                                                      position: 60

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

  Spree.admin.tables.policies.add :created_at,
                                        label: :created_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: true,
                                        default: false,
                                        position: 35

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
  Spree.admin.tables.register(:stock_transfers, model_class: Spree::StockTransfer, search_param: :number_or_reference_cont, link_to_action: :show)

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

  Spree.admin.tables.stock_transfers.add :updated_at,
                                               label: :updated_at,
                                               type: :datetime,
                                               sortable: true,
                                               filterable: true,
                                               default: false,
                                               position: 70

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
                                                         "#{count} #{Spree.t(md.resource_type.demodulize.downcase.pluralize.to_sym)}"
                                                       else
                                                         Spree.t(:not_available)
                                                       end
                                                     }

  Spree.admin.tables.metafield_definitions.add :created_at,
                                                     label: :created_at,
                                                     type: :datetime,
                                                     sortable: true,
                                                     filterable: true,
                                                     default: false,
                                                     position: 70

  Spree.admin.tables.metafield_definitions.add :updated_at,
                                                     label: :updated_at,
                                                     type: :datetime,
                                                     sortable: true,
                                                     filterable: true,
                                                     default: false,
                                                     position: 80

  # Register Gift Cards table
  Spree.admin.tables.register(:gift_cards, model_class: Spree::GiftCard, search_param: :code_i_cont, row_actions: false, link_to_action: :show)

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
                                          type: :money,
                                          sortable: true,
                                          filterable: true,
                                          default: true,
                                          position: 20,
                                          method: ->(gc) { gc.display_amount }

  Spree.admin.tables.gift_cards.add :used,
                                          label: :used,
                                          type: :money,
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
                                          search_url: ->(view_context) { view_context.spree.admin_users_select_options_path(format: :json) },
                                          method: ->(gc) { gc.user&.email }

  Spree.admin.tables.gift_cards.add :created_at,
                                          label: :created_at,
                                          type: :datetime,
                                          sortable: true,
                                          filterable: true,
                                          default: false,
                                          position: 80

  Spree.admin.tables.gift_cards.add :updated_at,
                                          label: :updated_at,
                                          type: :datetime,
                                          sortable: true,
                                          filterable: true,
                                          default: false,
                                          position: 90

  # Register Stock Items table
  Spree.admin.tables.register(:stock_items, model_class: Spree::StockItem, search_param: :variant_product_name_cont, row_actions: false, new_resource: false)

  # Variant with image (custom partial)
  Spree.admin.tables.stock_items.add :variant,
                                           label: :variant,
                                           type: :custom,
                                           sortable: false,
                                           filterable: true,
                                           default: true,
                                           position: 10,
                                           ransack_attribute: 'variant_product_name',
                                           partial: 'spree/admin/variants/variant',
                                           partial_locals: ->(record) { { variant: record.variant } }

  # Stock location
  Spree.admin.tables.stock_items.add :stock_location,
                                           label: :stock_location,
                                           type: :custom,
                                           filter_type: :autocomplete,
                                           sortable: false,
                                           filterable: true,
                                           default: true,
                                           position: 20,
                                           ransack_attribute: 'stock_location_id',
                                           operators: %i[eq],
                                           search_url: ->(view_context) { view_context.spree.admin_stock_locations_select_options_path(format: :json) },
                                           partial: 'spree/admin/tables/columns/stock_item_location'

  # Backorderable (inline editable checkbox)
  Spree.admin.tables.stock_items.add :backorderable,
                                           label: :backorderable,
                                           type: :custom,
                                           sortable: false,
                                           filterable: false,
                                           default: true,
                                           position: 30,
                                           partial: 'spree/admin/tables/columns/stock_item_backorderable'

  # Count on hand (inline editable number field)
  Spree.admin.tables.stock_items.add :count_on_hand,
                                           label: :count_on_hand,
                                           type: :custom,
                                           sortable: true,
                                           filterable: true,
                                           default: true,
                                           position: 40,
                                           partial: 'spree/admin/tables/columns/stock_item_count_on_hand'

  # SKU (filter-only)
  Spree.admin.tables.stock_items.add :sku,
                                           label: :sku,
                                           type: :string,
                                           sortable: false,
                                           filterable: true,
                                           displayable: false,
                                           default: false,
                                           position: 50,
                                           ransack_attribute: 'variant_sku'

  Spree.admin.tables.stock_items.add :created_at,
                                           label: :created_at,
                                           type: :datetime,
                                           sortable: true,
                                           filterable: true,
                                           default: false,
                                           position: 60

  Spree.admin.tables.stock_items.add :updated_at,
                                           label: :updated_at,
                                           type: :datetime,
                                           sortable: true,
                                           filterable: true,
                                           default: false,
                                           position: 70

  # ==========================================
  # Webhook Endpoints Table
  # ==========================================
  Spree.admin.tables.register(:webhook_endpoints, model_class: Spree::WebhookEndpoint, search_param: :url_cont, row_actions: false, link_to_action: :show)

  Spree.admin.tables.webhook_endpoints.add :url,
                                                 label: :url,
                                                 type: :link,
                                                 sortable: true,
                                                 filterable: true,
                                                 default: true,
                                                 position: 10

  Spree.admin.tables.webhook_endpoints.add :active,
                                                 label: :active,
                                                 type: :boolean,
                                                 sortable: true,
                                                 filterable: true,
                                                 default: true,
                                                 position: 20,
                                                 filter_type: :select,
                                                 value_options: [
                                                   { value: 'true', label: 'Active' },
                                                   { value: 'false', label: 'Inactive' }
                                                 ]

  Spree.admin.tables.webhook_endpoints.add :subscriptions_count,
                                                 label: 'admin.webhook_endpoints.events',
                                                 type: :string,
                                                 sortable: false,
                                                 filterable: false,
                                                 default: true,
                                                 position: 30,
                                                 method: ->(endpoint) { "#{endpoint.subscriptions.size} #{I18n.t('spree.admin.webhook_endpoints.events')}" }

  Spree.admin.tables.webhook_endpoints.add :deliveries_stats,
                                                 label: :deliveries,
                                                 type: :custom,
                                                 sortable: false,
                                                 filterable: false,
                                                 default: true,
                                                 position: 40,
                                                 partial: 'spree/admin/tables/columns/webhook_deliveries_stats'

  Spree.admin.tables.webhook_endpoints.add :created_at,
                                                 label: :created_at,
                                                 type: :datetime,
                                                 sortable: true,
                                                 filterable: true,
                                                 default: true,
                                                 position: 50

  Spree.admin.tables.webhook_endpoints.add :updated_at,
                                                 label: :updated_at,
                                                 type: :datetime,
                                                 sortable: true,
                                                 filterable: true,
                                                 default: false,
                                                 position: 60

  # ==========================================
  # Webhook Deliveries Table
  # ==========================================
  Spree.admin.tables.register(:webhook_deliveries, model_class: Spree::WebhookDelivery, search_param: :event_name_cont, row_actions: false, new_resource: false)

  Spree.admin.tables.webhook_deliveries.add :event_name,
                                                  label: :event,
                                                  type: :string,
                                                  sortable: true,
                                                  filterable: true,
                                                  default: true,
                                                  position: 10,
                                                  method: ->(delivery) { delivery.event_name }

  Spree.admin.tables.webhook_deliveries.add :status,
                                                  label: :status,
                                                  type: :custom,
                                                  sortable: false,
                                                  filterable: false,
                                                  default: true,
                                                  position: 20,
                                                  partial: 'spree/admin/tables/columns/webhook_delivery_status'

  Spree.admin.tables.webhook_deliveries.add :delivered_at,
                                                  label: :delivered_at,
                                                  type: :datetime,
                                                  sortable: true,
                                                  filterable: true,
                                                  default: true,
                                                  position: 30

  Spree.admin.tables.webhook_deliveries.add :execution_time,
                                                  label: :execution_time,
                                                  type: :string,
                                                  sortable: true,
                                                  filterable: false,
                                                  default: true,
                                                  position: 40,
                                                  method: ->(delivery) { delivery.execution_time ? "#{delivery.execution_time}ms" : '-' }

  Spree.admin.tables.webhook_deliveries.add :response_code,
                                                  label: :response_code,
                                                  type: :string,
                                                  sortable: true,
                                                  filterable: false,
                                                  default: true,
                                                  position: 50,
                                                  method: ->(delivery) { delivery.response_code || '-' }

  Spree.admin.tables.webhook_deliveries.add :actions,
                                                  label: :details,
                                                  type: :custom,
                                                  sortable: false,
                                                  filterable: false,
                                                  default: true,
                                                  position: 60,
                                                  partial: 'spree/admin/tables/columns/webhook_delivery_actions'

  Spree.admin.tables.webhook_deliveries.add :created_at,
                                                  label: :created_at,
                                                  type: :datetime,
                                                  sortable: true,
                                                  filterable: true,
                                                  default: false,
                                                  position: 70

  Spree.admin.tables.webhook_deliveries.add :updated_at,
                                                  label: :updated_at,
                                                  type: :datetime,
                                                  sortable: true,
                                                  filterable: true,
                                                  default: false,
                                                  position: 80

  # ==========================================
  # API Keys Table
  # ==========================================
  Spree.admin.tables.register(:api_keys, model_class: Spree::ApiKey, search_param: :name_cont, row_actions: false, link_to_action: :show)

  Spree.admin.tables.api_keys.add :name,
                                        label: :name,
                                        type: :link,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 10

  Spree.admin.tables.api_keys.add :key_type,
                                        label: 'admin.api_keys.key_type',
                                        type: :custom,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 20,
                                        partial: 'spree/admin/tables/columns/api_key_type',
                                        filter_type: :select,
                                        value_options: [
                                          { value: 'publishable', label: 'Publishable' },
                                          { value: 'secret', label: 'Secret' }
                                        ]

  Spree.admin.tables.api_keys.add :status,
                                        label: :status,
                                        type: :custom,
                                        sortable: false,
                                        filterable: false,
                                        default: true,
                                        position: 30,
                                        partial: 'spree/admin/tables/columns/api_key_status'

  Spree.admin.tables.api_keys.add :last_used_at,
                                        label: 'admin.api_keys.last_used_at',
                                        type: :datetime,
                                        sortable: true,
                                        filterable: false,
                                        default: true,
                                        position: 40

  Spree.admin.tables.api_keys.add :created_at,
                                        label: :created_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: true,
                                        default: true,
                                        position: 50

  Spree.admin.tables.api_keys.add :updated_at,
                                        label: :updated_at,
                                        type: :datetime,
                                        sortable: true,
                                        filterable: true,
                                        default: false,
                                        position: 60

  # ==========================================
  # Price Lists Table
  # ==========================================
  Spree.admin.tables.register(:price_lists, model_class: Spree::PriceList, search_param: :name_cont, link_to_action: :show)

  Spree.admin.tables.price_lists.add :name,
                                           label: :name,
                                           type: :link,
                                           sortable: true,
                                           filterable: true,
                                           default: true,
                                           position: 10

  Spree.admin.tables.price_lists.add :status,
                                           label: :status,
                                           type: :custom,
                                           filter_type: :select,
                                           sortable: true,
                                           filterable: true,
                                           default: true,
                                           position: 20,
                                           partial: 'spree/admin/tables/columns/price_list_status',
                                           value_options: [
                                             { value: 'draft', label: 'Draft' },
                                             { value: 'active', label: 'Active' },
                                             { value: 'scheduled', label: 'Scheduled' },
                                             { value: 'inactive', label: 'Inactive' }
                                           ]

  Spree.admin.tables.price_lists.add :starts_at,
                                           label: :starts_at,
                                           type: :datetime,
                                           sortable: true,
                                           filterable: true,
                                           default: true,
                                           position: 30

  Spree.admin.tables.price_lists.add :ends_at,
                                           label: :ends_at,
                                           type: :datetime,
                                           sortable: true,
                                           filterable: true,
                                           default: true,
                                           position: 40

  Spree.admin.tables.price_lists.add :created_at,
                                           label: :created_at,
                                           type: :datetime,
                                           sortable: true,
                                           filterable: true,
                                           default: false,
                                           position: 50

  Spree.admin.tables.price_lists.add :updated_at,
                                           label: :updated_at,
                                           type: :datetime,
                                           sortable: true,
                                           filterable: true,
                                           default: false,
                                           position: 60

  # ==========================================
  # Price List Products Table
  # ==========================================
  Spree.admin.tables.register(:price_list_products, model_class: Spree::Product, search_param: :multi_search, row_actions: false, new_resource: false)

  Spree.admin.tables.price_list_products.add :name,
                                                   label: :name,
                                                   type: :custom,
                                                   sortable: true,
                                                   filterable: true,
                                                   default: true,
                                                   position: 10,
                                                   partial: 'spree/admin/tables/columns/product_name'

  Spree.admin.tables.price_list_products.add :status,
                                                   label: :status,
                                                   type: :custom,
                                                   filter_type: :status,
                                                   sortable: true,
                                                   filterable: true,
                                                   default: true,
                                                   position: 20,
                                                   partial: 'spree/admin/tables/columns/product_status',
                                                   ransack_attribute: 'status',
                                                   value_options: -> { Spree::Product::STATUSES.map { |s| { value: s, label: s.humanize } } }

  Spree.admin.tables.price_list_products.add :inventory,
                                                   label: :inventory,
                                                   type: :custom,
                                                   sortable: false,
                                                   filterable: false,
                                                   default: true,
                                                   position: 30,
                                                   partial: 'spree/admin/tables/columns/product_inventory'

  Spree.admin.tables.price_list_products.add :created_at,
                                                   label: :created_at,
                                                   type: :datetime,
                                                   sortable: true,
                                                   filterable: true,
                                                   default: false,
                                                   position: 50

  Spree.admin.tables.price_list_products.add :updated_at,
                                                   label: :updated_at,
                                                   type: :datetime,
                                                   sortable: true,
                                                   filterable: true,
                                                   default: false,
                                                   position: 60

  Spree.admin.tables.price_list_products.add_bulk_action :remove_from_price_list,
                                                               label: 'admin.bulk_ops.price_list_products.title.remove',
                                                               icon: 'trash',
                                                               action_path: ->(view_context) { view_context.spree.bulk_destroy_admin_price_list_products_path(view_context.instance_variable_get(:@price_list)) },
                                                               body: 'admin.bulk_ops.price_list_products.body.remove',
                                                               button_text: :remove,
                                                               button_class: 'btn-danger',
                                                               method: :delete,
                                                               position: 10

  # ==========================================
  # Customer Groups Table
  # ==========================================
  Spree.admin.tables.register(:customer_groups, model_class: Spree::CustomerGroup, search_param: :name_cont, link_to_action: :show)

  Spree.admin.tables.customer_groups.add :name,
                                               label: :name,
                                               type: :link,
                                               sortable: true,
                                               filterable: true,
                                               default: true,
                                               position: 10

  Spree.admin.tables.customer_groups.add :description,
                                               label: :description,
                                               type: :string,
                                               sortable: false,
                                               filterable: false,
                                               default: true,
                                               position: 20,
                                               method: ->(cg) { cg.description.to_s.truncate(50) }

  Spree.admin.tables.customer_groups.add :users_count,
                                               label: :customers,
                                               type: :number,
                                               sortable: false,
                                               filterable: false,
                                               default: true,
                                               position: 30,
                                               method: ->(cg) { cg.users_count }

  Spree.admin.tables.customer_groups.add :created_at,
                                               label: :created_at,
                                               type: :datetime,
                                               sortable: true,
                                               filterable: true,
                                               default: false,
                                               position: 40

  Spree.admin.tables.customer_groups.add :updated_at,
                                               label: :updated_at,
                                               type: :datetime,
                                               sortable: true,
                                               filterable: true,
                                               default: true,
                                               position: 50

  # ==========================================
  # Customer Group Users Table (users within a customer group)
  # ==========================================
  Spree.admin.tables.register(:customer_group_users, model_class: Spree.user_class, search_param: :multi_search, row_actions: false, new_resource: false)

  Spree.admin.tables.customer_group_users.add :name,
                                                    label: :name,
                                                    type: :custom,
                                                    sortable: true,
                                                    filterable: false,
                                                    default: true,
                                                    position: 10,
                                                    ransack_attribute: 'first_name',
                                                    partial: 'spree/admin/shared/user',
                                                    partial_locals: ->(record) { { user: record } }

  Spree.admin.tables.customer_group_users.add :location,
                                                    label: :location,
                                                    type: :custom,
                                                    sortable: false,
                                                    filterable: false,
                                                    default: false,
                                                    position: 20,
                                                    partial: 'spree/admin/tables/columns/user_location'

  Spree.admin.tables.customer_group_users.add :created_at,
                                                    label: :added_at,
                                                    type: :datetime,
                                                    sortable: true,
                                                    filterable: false,
                                                    default: true,
                                                    position: 30

  Spree.admin.tables.customer_group_users.add_bulk_action :remove_from_customer_group,
                                                                label: 'admin.bulk_ops.customer_group_users.title.remove',
                                                                icon: 'trash',
                                                                action_path: ->(view_context) { view_context.spree.bulk_destroy_admin_customer_group_customer_group_users_path(view_context.instance_variable_get(:@customer_group)) },
                                                                body: 'admin.bulk_ops.customer_group_users.body.remove',
                                                                button_text: :remove,
                                                                button_class: 'btn-danger',
                                                                method: :delete,
                                                                position: 10

  # ==========================================
  # Register Markets table
  # ==========================================
  Spree.admin.tables.register(:markets, model_class: Spree::Market, search_param: :name_cont)

  Spree.admin.tables.markets.add :name,
                                       label: :name,
                                       type: :string,
                                       sortable: true,
                                       filterable: true,
                                       default: true,
                                       position: 10

  Spree.admin.tables.markets.add :currency,
                                       label: :currency,
                                       type: :string,
                                       sortable: true,
                                       default: true,
                                       position: 20

  Spree.admin.tables.markets.add :default_locale,
                                       label: :default_locale,
                                       type: :string,
                                       sortable: true,
                                       default: true,
                                       position: 30

  Spree.admin.tables.markets.add :default,
                                       label: :default,
                                       type: :boolean,
                                       sortable: true,
                                       default: true,
                                       position: 40
end
