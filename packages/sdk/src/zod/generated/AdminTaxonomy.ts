// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminMetafieldSchema } from './AdminMetafield';
import { AdminTaxonSchema } from './AdminTaxon';

export const AdminTaxonomySchema = z.object({
  id: z.string(),
  name: z.string(),
  position: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  root_id: z.string().nullable(),
  root: z.lazy(() => AdminTaxonSchema).optional(),
  taxons: z.array(z.lazy(() => AdminTaxonSchema)).optional(),
  metafields: z.array(AdminMetafieldSchema).optional(),
});

export type AdminTaxonomy = z.infer<typeof AdminTaxonomySchema>;
