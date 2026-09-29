// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CategorySchema } from './Category';
import { ChannelSchema } from './Channel';
import { CollectionSchema } from './Collection';
import { CustomFieldSchema } from './CustomField';
import { DigitalAssetSchema } from './DigitalAsset';
import { MediaSchema } from './Media';
import { OptionTypeSchema } from './OptionType';
import { OptionValueSchema } from './OptionValue';
import { PriceSchema } from './Price';
import { PriceHistorySchema } from './PriceHistory';
import { ProductPublicationSchema } from './ProductPublication';
import { ProductSubmissionSchema } from './ProductSubmission';
import { ProductTypeSchema } from './ProductType';
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
  price: z.lazy(() => PriceSchema).nullable(),
  original_price: z.lazy(() => PriceSchema).nullable(),
  seller_id: z.string().nullable(),
  seller: SellerSchema.optional(),
  primary_media: MediaSchema.optional(),
  media: z.array(MediaSchema).optional(),
  variants: z.array(z.lazy(() => VariantSchema)).optional(),
  default_variant: z.lazy(() => VariantSchema).optional(),
  option_types: z.array(z.lazy(() => OptionTypeSchema)).optional(),
  option_values: z.array(z.lazy(() => OptionValueSchema)).optional(),
  categories: z.array(z.lazy(() => CategorySchema)).optional(),
  custom_fields: z.array(CustomFieldSchema).optional(),
  prior_price: PriceHistorySchema.nullable().optional(),
  external_references: z.record(z.string(), z.string()),
  translations: z.record(z.string(), z.record(z.string(), z.union([z.string(), z.number()]).nullable())).optional(),
  status: z.string(),
  metadata: z.record(z.string(), z.unknown()),
  deleted_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  delivery_profile_id: z.string().nullable(),
  submission: ProductSubmissionSchema.nullable().optional(),
  seller_name: z.string().nullable(),
  product_type_id: z.string().nullable(),
  tax_category_id: z.string().nullable(),
  digital_assets: z.array(DigitalAssetSchema).optional(),
  collections: z.array(CollectionSchema).optional(),
  product_publications: z.array(ProductPublicationSchema).optional(),
  channels: z.array(ChannelSchema).optional(),
  product_type: ProductTypeSchema.optional(),
});

export type Product = z.infer<typeof ProductSchema>;
