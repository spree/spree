// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminMetafieldSchema } from './AdminMetafield';
import { AdminOptionValueSchema } from './AdminOptionValue';

export const AdminOptionTypeSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  name: z.string(),
  presentation: z.string(),
  position: z.number(),
  filterable: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  option_values: z.array(z.lazy(() => AdminOptionValueSchema)),
  metafields: z.array(AdminMetafieldSchema).optional(),
});

export type AdminOptionType = z.infer<typeof AdminOptionTypeSchema>;
