// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreSchema = z.object({
  id: z.string(),
  name: z.string(),
  seller_digital_assets_enabled: z.boolean(),
  seller_digital_asset_content_types: z.array(z.string()),
});

export type Store = z.infer<typeof StoreSchema>;
