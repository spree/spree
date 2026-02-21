// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreCurrencySchema = z.object({
  iso_code: z.string(),
  name: z.string(),
  symbol: z.string(),
});

export type StoreCurrency = z.infer<typeof StoreCurrencySchema>;
