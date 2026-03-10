// Request parameter types for Admin API endpoints
// Based on the Admin API OpenAPI specification

export interface StoreUpdateParams {
  name?: string;
  url?: string;
  mail_from_address?: string;
  customer_support_email?: string;
  new_order_notifications_email?: string;
  description?: string;
  address?: string;
  contact_phone?: string;
  seo_title?: string;
  meta_keywords?: string;
  meta_description?: string;
  default_currency?: string;
  default_locale?: string;
  supported_currencies?: string;
  supported_locales?: string;
}

export interface OptionTypeCreateParams {
  name: string;
  presentation: string;
  position?: number;
  filterable?: boolean;
  option_values?: Array<{
    name?: string;
    presentation?: string;
    position?: number;
  }>;
}

export interface OptionTypeUpdateParams {
  name?: string;
  presentation?: string;
  position?: number;
  filterable?: boolean;
  option_values?: Array<{
    id?: string;
    name?: string;
    presentation?: string;
    position?: number;
  }>;
}

export interface AdjustmentCreateParams {
  amount: number;
  label: string;
}

export interface AdjustmentUpdateParams {
  amount?: number;
  label?: string;
  eligible?: boolean;
}

export interface LineItemCreateParams {
  variant_id: string;
  quantity?: number;
}

export interface LineItemUpdateParams {
  quantity?: number;
}

export interface PaymentCreateParams {
  payment_method_id: string;
  amount?: number;
  source_id?: string;
}

export interface RefundCreateParams {
  payment_id: string;
  amount: number;
  refund_reason_id?: string;
}

export interface ShipmentUpdateParams {
  tracking?: string;
  selected_shipping_rate_id?: string;
}

export interface OrderCreateParams {
  email?: string;
  user_id?: string;
  currency?: string;
  channel?: string;
  internal_note?: string;
}

export interface OrderUpdateParams {
  email?: string;
  special_instructions?: string;
  internal_note?: string;
  channel?: string;
  ship_address?: {
    firstname?: string;
    lastname?: string;
    address1?: string;
    city?: string;
    zipcode?: string;
    country_iso?: string;
    state_abbr?: string;
    phone?: string;
  };
  bill_address?: {
    firstname?: string;
    lastname?: string;
    address1?: string;
    city?: string;
    zipcode?: string;
    country_iso?: string;
    state_abbr?: string;
    phone?: string;
  };
  line_items?: Array<{
    variant_id?: string;
    quantity?: number;
  }>;
}

export interface DirectUploadCreateParams {
  blob: {
    filename: string;
    byte_size: number;
    checksum: string;
    content_type: string;
  };
}

export interface AssetCreateParams {
  alt?: string;
  position?: number;
  type?: string;
  url?: string;
  signed_id?: string;
}

export interface AssetUpdateParams {
  alt?: string;
  position?: number;
}

export interface ProductCreateParams {
  name: string;
  price: number;
  description?: string;
  slug?: string;
  status?: 'draft' | 'active' | 'archived';
  sku?: string;
  shipping_category_id: string;
  tax_category_id?: string;
  taxon_ids?: Array<string>;
  tags?: Array<string>;
  variants?: Array<{
    sku?: string;
    price?: number;
    option_type?: string;
    option_value?: string;
    total_on_hand?: number;
    prices?: Array<{
      currency: string;
      amount: number;
      compare_at_amount?: number;
    }>;
  }>;
}

export interface ProductUpdateParams {
  name?: string;
  price?: number;
  description?: string;
  slug?: string;
  status?: 'draft' | 'active' | 'archived';
  sku?: string;
  shipping_category_id?: string;
  tax_category_id?: string;
  taxon_ids?: Array<string>;
  tags?: Array<string>;
  variants?: Array<{
    sku?: string;
    price?: number;
    option_type?: string;
    option_value?: string;
    total_on_hand?: number;
    prices?: Array<{
      currency: string;
      amount: number;
      compare_at_amount?: number;
    }>;
  }>;
}

export interface TaxonomyCreateParams {
  name: string;
  position?: number;
}

export interface TaxonomyUpdateParams {
  name?: string;
  position?: number;
}

export interface TaxonCreateParams {
  name: string;
  parent_id?: string;
  position?: number;
  description?: string;
  permalink?: string;
  meta_title?: string;
  meta_description?: string;
  meta_keywords?: string;
  hide_from_nav?: boolean;
  sort_order?: string;
}

export interface TaxonUpdateParams {
  name?: string;
  parent_id?: string;
  position?: number;
  description?: string;
  permalink?: string;
  meta_title?: string;
  meta_description?: string;
  meta_keywords?: string;
  hide_from_nav?: boolean;
  sort_order?: string;
}

export interface VariantCreateParams {
  sku?: string;
  price?: number;
  compare_at_price?: number;
  cost_price?: number;
  cost_currency?: string;
  weight?: number;
  height?: number;
  width?: number;
  depth?: number;
  weight_unit?: string;
  dimensions_unit?: string;
  track_inventory?: boolean;
  tax_category_id?: string;
  option_type?: string;
  option_value?: string;
  total_on_hand?: number;
  position?: number;
  barcode?: string;
  prices?: Array<{
    currency: string;
    amount: number;
    compare_at_amount?: number;
  }>;
  stock_items?: Array<{
    stock_location_id?: string;
    count_on_hand?: number;
    backorderable?: boolean;
  }>;
}

export interface VariantUpdateParams {
  sku?: string;
  price?: number;
  compare_at_price?: number;
  cost_price?: number;
  cost_currency?: string;
  weight?: number;
  height?: number;
  width?: number;
  depth?: number;
  weight_unit?: string;
  dimensions_unit?: string;
  track_inventory?: boolean;
  tax_category_id?: string;
  option_type?: string;
  option_value?: string;
  total_on_hand?: number;
  position?: number;
  barcode?: string;
  prices?: Array<{
    currency: string;
    amount: number;
    compare_at_amount?: number;
  }>;
  stock_items?: Array<{
    stock_location_id?: string;
    count_on_hand?: number;
    backorderable?: boolean;
  }>;
}
