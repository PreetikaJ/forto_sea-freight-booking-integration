-- Custom test: Ensure no duplicate shipment_ids in dim_carrier_bookings
-- The dimensional table must have exactly one row per shipment.
-- This is a critical data quality test — duplicates would break downstream joins
-- and cause volume double-counting.

select
    shipment_id,
    count(*) as row_count
from {{ ref('dim_carrier_bookings') }}
group by shipment_id
having count(*) > 1
