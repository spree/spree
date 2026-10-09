// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { PurchaseOrderItemSchema } from './PurchaseOrderItem';
import { StockLocationSchema } from './StockLocation';
import { StockReceiptSchema } from './StockReceipt';
import { SupplierSchema } from './Supplier';

export const PurchaseOrderSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  currency: z.string(),
  reference: z.string().nullable(),
  notes: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  close_reason: z.string().nullable(),
  items_count: z.number(),
  quantity_received_total: z.number(),
  quantity_rejected_total: z.number(),
  ordered_at: z.string().nullable(),
  received_at: z.string().nullable(),
  closed_short_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  expected_at: z.string().nullable(),
  cancel_by: z.string().nullable(),
  closed_short: z.boolean(),
  quantity_ordered_total: z.number(),
  editable: z.boolean(),
  subtotal: z.string(),
  supplier_id: z.string().nullable(),
  destination_location_id: z.string().nullable(),
  items: z.array(PurchaseOrderItemSchema).optional(),
  stock_receipts: z.array(StockReceiptSchema).optional(),
  supplier: SupplierSchema.optional(),
  destination_location: StockLocationSchema.optional(),
});

export type PurchaseOrder = z.infer<typeof PurchaseOrderSchema>;
