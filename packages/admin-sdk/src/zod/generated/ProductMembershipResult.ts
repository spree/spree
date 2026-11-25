// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductMembershipResultSchema = z.object({
  added_count: z.number().optional(),
  removed_count: z.number().optional(),
});

export type ProductMembershipResult = z.infer<typeof ProductMembershipResultSchema>;
