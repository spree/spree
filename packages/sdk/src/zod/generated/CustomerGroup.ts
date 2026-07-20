// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CustomerGroupSchema = z.object({
  id: z.string(),
  name: z.string(),
});

export type CustomerGroup = z.infer<typeof CustomerGroupSchema>;
