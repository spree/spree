// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminMetafieldSchema } from './AdminMetafield';
import { StoreTaxonSchema } from './StoreTaxon';

export const AdminTaxonSchema = z.object({
  id: z.string(),
  name: z.string(),
  permalink: z.string(),
  position: z.number(),
  depth: z.number(),
  meta_title: z.string().nullable(),
  meta_description: z.string().nullable(),
  meta_keywords: z.string().nullable(),
  children_count: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  parent_id: z.string().nullable(),
  taxonomy_id: z.string(),
  description: z.string(),
  description_html: z.string(),
  image_url: z.string().nullable(),
  square_image_url: z.string().nullable(),
  is_root: z.boolean(),
  is_child: z.boolean(),
  is_leaf: z.boolean(),
  parent: z.lazy(() => StoreTaxonSchema).optional(),
  children: z.array(z.lazy(() => StoreTaxonSchema)).optional(),
  ancestors: z.array(z.lazy(() => StoreTaxonSchema)).optional(),
  metafields: z.array(AdminMetafieldSchema).optional(),
  lft: z.number(),
  rgt: z.number(),
});

export type AdminTaxon = z.infer<typeof AdminTaxonSchema>;
