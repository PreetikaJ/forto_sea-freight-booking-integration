-- Custom test: Reconciliation check — verify that the is_confirmed_volume flag
-- in the enriched fact table matches the source for legacy shipments.
-- For shipments NOT in dim_carrier_bookings, the enriched flag should match
-- the original shipments.is_confirmed_volume.
-- This test catches regressions where the join logic might alter legacy data.

select
    f.house_shipment_id,
    f.shipment_id,
    f.is_confirmed_volume as enriched_flag,
    s.is_confirmed_volume as source_flag,
    f.confirmed_volume_source
from {{ ref('shipment_volume_enriched') }} f
join {{ source('forto_data_raw', 'shipments') }} s on f.shipment_id = s.shipment_id
where
    f.confirmed_volume_source = 'shipments_legacy'
    and f.is_confirmed_volume is not null
    and s.is_confirmed_volume is not null
    and f.is_confirmed_volume != s.is_confirmed_volume
