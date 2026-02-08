// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreMetafieldSchema } from './StoreMetafield';
import { StoreTaxonSchema } from './StoreTaxon';

export const StoreTaxonomySchema = z.object({
  id: z.string(),
  name: z.string(),
  position: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  root_id: z.string().nullable(),
  root: z.lazy(() => StoreTaxonSchema).optional(),
  taxons: z.array(z.lazy(() => StoreTaxonSchema)).optional(),
  metafields: z.array(StoreMetafieldSchema).optional(),
});

export type StoreTaxonomy = z.infer<typeof StoreTaxonomySchema>;
