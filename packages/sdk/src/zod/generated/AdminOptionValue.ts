// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminMetafieldSchema } from './AdminMetafield';
import { AdminOptionTypeSchema } from './AdminOptionType';

export const AdminOptionValueSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  option_type_id: z.string(),
  name: z.string(),
  presentation: z.string(),
  position: z.number(),
  option_type_name: z.string(),
  option_type_presentation: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  option_type: z.lazy(() => AdminOptionTypeSchema).optional(),
  metafields: z.array(AdminMetafieldSchema).optional(),
});

export type AdminOptionValue = z.infer<typeof AdminOptionValueSchema>;
