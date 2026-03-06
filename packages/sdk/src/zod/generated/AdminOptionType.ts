// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreOptionValueSchema } from './StoreOptionValue';

export const AdminOptionTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  presentation: z.string(),
  position: z.number(),
  filterable: z.boolean(),
  option_values: z.array(StoreOptionValueSchema),
});

export type AdminOptionType = z.infer<typeof AdminOptionTypeSchema>;
