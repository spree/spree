// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminMetafieldSchema } from './AdminMetafield';
import { StoreTaxonSchema } from './StoreTaxon';

export const AdminTaxonomySchema = z.object({
  id: z.string(),
  name: z.string(),
  position: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  root_id: z.string().nullable(),
  root: z.lazy(() => StoreTaxonSchema).optional(),
  taxons: z.array(z.lazy(() => StoreTaxonSchema)).optional(),
  metafields: z.array(AdminMetafieldSchema).optional(),
});

export type AdminTaxonomy = z.infer<typeof AdminTaxonomySchema>;
