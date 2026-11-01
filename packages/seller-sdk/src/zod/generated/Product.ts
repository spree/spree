// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Product from '../../types/generated/Product';
import { CategorySchema } from './Category';
import { CustomFieldSchema } from './CustomField';
import { MediaSchema } from './Media';
import { OptionTypeSchema } from './OptionType';
import { OptionValueSchema } from './OptionValue';
import { PriceSchema } from './Price';
import { PriceHistorySchema } from './PriceHistory';
import { ProductSubmissionSchema } from './ProductSubmission';
import { SellerSchema } from './Seller';
import { VariantSchema } from './Variant';

export const ProductSchema = z.object({
  id: z.string(),
  name: z.string(),
  slug: z.string(),
  meta_title: z.string().nullable(),
  meta_description: z.string().nullable(),
  meta_keywords: z.string().nullable(),
  variant_count: z.number(),
  available_on: z.string().nullable(),
  preorder_ships_at: z.string().nullable(),
  purchasable: z.boolean(),
  preorder: z.boolean(),
  in_stock: z.boolean(),
  backorderable: z.boolean(),
  available: z.boolean(),
  description: z.string().nullable(),
  description_html: z.string().nullable(),
  default_variant_id: z.string(),
  buy_box_variant_id: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
  tags: z.array(z.string()),
  price: PriceSchema,
  original_price: PriceSchema.nullable(),
  seller_id: z.string().nullable(),
  seller: SellerSchema.optional(),
  primary_media: MediaSchema.optional(),
  media: z.array(MediaSchema).optional(),
  get variants() { return z.array(VariantSchema).optional(); },
  get default_variant() { return VariantSchema.optional(); },
  option_types: z.array(OptionTypeSchema).optional(),
  option_values: z.array(OptionValueSchema).optional(),
  get categories() { return z.array(CategorySchema).optional(); },
  custom_fields: z.array(CustomFieldSchema).optional(),
  prior_price: PriceHistorySchema.nullable().optional(),
  status: z.string(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  product_type_id: z.string().nullable(),
  delivery_profile_id: z.string().nullable(),
  submission: ProductSubmissionSchema.nullable().optional(),
}) as unknown as z.ZodObject<{
  id: z.ZodType<Product['id']>;
  name: z.ZodType<Product['name']>;
  slug: z.ZodType<Product['slug']>;
  meta_title: z.ZodType<Product['meta_title']>;
  meta_description: z.ZodType<Product['meta_description']>;
  meta_keywords: z.ZodType<Product['meta_keywords']>;
  variant_count: z.ZodType<Product['variant_count']>;
  available_on: z.ZodType<Product['available_on']>;
  preorder_ships_at: z.ZodType<Product['preorder_ships_at']>;
  purchasable: z.ZodType<Product['purchasable']>;
  preorder: z.ZodType<Product['preorder']>;
  in_stock: z.ZodType<Product['in_stock']>;
  backorderable: z.ZodType<Product['backorderable']>;
  available: z.ZodType<Product['available']>;
  description: z.ZodType<Product['description']>;
  description_html: z.ZodType<Product['description_html']>;
  default_variant_id: z.ZodType<Product['default_variant_id']>;
  buy_box_variant_id: z.ZodType<Product['buy_box_variant_id']>;
  thumbnail_url: z.ZodType<Product['thumbnail_url']>;
  tags: z.ZodType<Product['tags']>;
  price: z.ZodType<Product['price']>;
  original_price: z.ZodType<Product['original_price']>;
  seller_id: z.ZodType<Product['seller_id']>;
  seller: z.ZodOptional<z.ZodType<Exclude<Product['seller'], undefined>>>;
  primary_media: z.ZodOptional<z.ZodType<Exclude<Product['primary_media'], undefined>>>;
  media: z.ZodOptional<z.ZodType<Exclude<Product['media'], undefined>>>;
  variants: z.ZodOptional<z.ZodType<Exclude<Product['variants'], undefined>>>;
  default_variant: z.ZodOptional<z.ZodType<Exclude<Product['default_variant'], undefined>>>;
  option_types: z.ZodOptional<z.ZodType<Exclude<Product['option_types'], undefined>>>;
  option_values: z.ZodOptional<z.ZodType<Exclude<Product['option_values'], undefined>>>;
  categories: z.ZodOptional<z.ZodType<Exclude<Product['categories'], undefined>>>;
  custom_fields: z.ZodOptional<z.ZodType<Exclude<Product['custom_fields'], undefined>>>;
  prior_price: z.ZodOptional<z.ZodType<Exclude<Product['prior_price'], undefined>>>;
  status: z.ZodType<Product['status']>;
  metadata: z.ZodType<Product['metadata']>;
  created_at: z.ZodType<Product['created_at']>;
  updated_at: z.ZodType<Product['updated_at']>;
  product_type_id: z.ZodType<Product['product_type_id']>;
  delivery_profile_id: z.ZodType<Product['delivery_profile_id']>;
  submission: z.ZodOptional<z.ZodType<Exclude<Product['submission'], undefined>>>;
}>;

export type { Product };
