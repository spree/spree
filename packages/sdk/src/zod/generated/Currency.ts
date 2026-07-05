// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CurrencySchema = z.object({
  iso_code: z.string(),
  name: z.string(),
  symbol: z.string(),
});

export type Currency = z.infer<typeof CurrencySchema>;
