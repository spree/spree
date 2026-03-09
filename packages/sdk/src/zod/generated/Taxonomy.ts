// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { MetafieldSchema } from './Metafield';
import { TaxonSchema } from './Taxon';

export const TaxonomySchema = z.object({
  id: z.string(),
  name: z.string(),
  position: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  root_id: z.string().nullable(),
  root: z.lazy(() => TaxonSchema).optional(),
  taxons: z.array(z.lazy(() => TaxonSchema)).optional(),
  metafields: z.array(MetafieldSchema).optional(),
});

export type Taxonomy = z.infer<typeof TaxonomySchema>;
