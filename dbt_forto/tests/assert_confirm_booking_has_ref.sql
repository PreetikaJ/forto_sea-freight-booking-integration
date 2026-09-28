-- Custom test: Confirmed bookings must have a carrier_booking_reference
-- Business rule: A confirmed booking (secured space) should always have a
-- carrier-assigned reference. Missing references for confirmed bookings
-- indicate a data pipeline issue.

select
    shipment_id,
    carrier_booking_id,
    carrier_booking_state,
    carrier_booking_reference
from {{ ref('dim_carrier_bookings') }}
where
    carrier_booking_state = 'confirmed'
    and (carrier_booking_reference is null or carrier_booking_reference = '')