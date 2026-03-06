// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminOptionValueSchema } from './AdminOptionValue';

export const AdminOptionTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  presentation: z.string(),
  position: z.number(),
  filterable: z.boolean(),
  option_values: z.array(AdminOptionValueSchema),
});

export type AdminOptionType = z.infer<typeof AdminOptionTypeSchema>;
