// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomFieldSchema } from './CustomField';

export const CategorySchema: z.ZodObject<any> = z.object({
  id: z.string(),
  name: z.string(),
  permalink: z.string(),
  position: z.number(),
  depth: z.number(),
  meta_title: z.string().nullable(),
  meta_description: z.string().nullable(),
  meta_keywords: z.string().nullable(),
  children_count: z.number(),
  parent_id: z.string().nullable(),
  description: z.string(),
  description_html: z.string(),
  image_url: z.string().nullable(),
  square_image_url: z.string().nullable(),
  is_root: z.boolean(),
  is_child: z.boolean(),
  is_leaf: z.boolean(),
  parent: z.lazy(() => CategorySchema).optional(),
  children: z.array(z.lazy(() => CategorySchema)).optional(),
  ancestors: z.array(z.lazy(() => CategorySchema)).optional(),
  custom_fields: z.array(CustomFieldSchema).optional(),
  external_references: z.record(z.string(), z.string()),
  translations: z.record(z.string(), z.record(z.string(), z.union([z.string(), z.number()]).nullable())).optional(),
  metadata: z.record(z.string(), z.unknown()),
  pretty_name: z.string(),
  lft: z.number(),
  rgt: z.number(),
  products_count: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type Category = z.infer<typeof CategorySchema>;
