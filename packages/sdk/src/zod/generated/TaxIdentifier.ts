// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxIdentifierSchema = z.object({
  id: z.string(),
  kind: z.string(),
  value: z.string(),
});

export type TaxIdentifier = z.infer<typeof TaxIdentifierSchema>;
