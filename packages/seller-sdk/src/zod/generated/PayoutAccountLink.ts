// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PayoutAccountLinkSchema = z.object({
  url: z.string().nullable(),
});

export type PayoutAccountLink = z.infer<typeof PayoutAccountLinkSchema>;
