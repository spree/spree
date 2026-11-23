// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailParcelItemSchema } from './EmailParcelItem';
import { EmailStockLocationSchema } from './EmailStockLocation';

export const EmailFulfillmentGroupSchema = z.object({
  name: z.string().nullable(),
  unpriced: z.boolean(),
  cost: z.string(),
  seller_names: z.array(z.string()),
  pickup_location: EmailStockLocationSchema.nullable(),
  items: z.array(EmailParcelItemSchema),
});

export type EmailFulfillmentGroup = z.infer<typeof EmailFulfillmentGroupSchema>;
