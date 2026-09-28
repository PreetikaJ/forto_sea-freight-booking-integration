{{ config(
    materialized='table'
  ) 
}}

with standardized_bookings as (
    select * 
    from {{ source('forto_curated', 'forto_carrier_bookings') }}
),

-- Calculate total booking attempts per shipment (for audit/analysis)
attempt_counts as (
    select
        shipment_id,
        count(*) as total_booking_attempts
    from standardized_bookings
    where
        shipment_id is not null
        and shipment_id != ''
    group by shipment_id
),

-- Rank all booking records per shipment by recency of update.
-- The most recently updated record represents the current booking state.
ranked_bookings as (
    select
        sb.*,
        ac.total_booking_attempts,
        row_number() over (
            partition by sb.shipment_id
            order by
                sb.updated_at desc,
                sb.booking_attempt desc,
                case sb.carrier_booking_state
                    when 'confirmed' then 5
                    when 'contacted' then 4
                    when 'pending'   then 3
                    when 'cancelled' then 2
                    when 'failed'    then 1
                    else 0
                end desc
        ) as recency_rank
    from standardized_bookings sb
    inner join attempt_counts ac on sb.shipment_id = ac.shipment_id
    where
        sb.shipment_id is not null
        and sb.shipment_id != ''
),

-- Select the winning record per shipment (rank = 1)
dim_carrier_bookings as (
    select
        shipment_id,
        carrier_booking_id,
        carrier_booking_reference,
        booking_attempt,
        carrier_code,
        carrier_name,
        carrier_booking_state,
        is_volume_confirmed,
        carrier_booking_source,
        integration_method,
        is_spot_booking,
        container_types,
        has_dangerous_goods,
        has_reefer_container,
        has_non_reefer_container,
        total_booking_attempts,
        case when total_booking_attempts > 1 then true else false end as has_multiple_attempts,
        created_at,
        updated_at,
        publish_time,
        current_timestamp() as dbt_loaded_at
    from ranked_bookings
    where recency_rank = 1
)

select * from dim_carrier_bookings