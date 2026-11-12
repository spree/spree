// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailCustomerGroupSchema = z.object({
  id: z.string(),
  name: z.string(),
});

export type EmailCustomerGroup = z.infer<typeof EmailCustomerGroupSchema>;
