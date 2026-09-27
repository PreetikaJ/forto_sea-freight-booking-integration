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
                -- Tie-breaker 1: Most recently updated record wins
                sb.updated_at desc,
                -- Tie-breaker 2: Highest booking attempt wins (later attempts are more current)
                sb.booking_attempt desc,
                -- Tie-breaker 3: Confirmed > contacted > pending > cancelled > failed
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
        -- Primary key (one row per shipment)
        shipment_id,
        -- Carrier booking reference fields
        carrier_booking_id,
        carrier_booking_reference,
        booking_attempt,
        -- Carrier dimension attributes
        carrier_code,
        carrier_name,
        -- Booking status (the current/active state)
        carrier_booking_state,
        is_volume_confirmed,
        -- Booking source and integration
        carrier_booking_source,
        integration_method,
        is_spot_booking,
        -- Container and cargo attributes
        container_types,
        has_dangerous_goods,
        has_reefer_container,
        has_non_reefer_container,
        -- Audit fields
        total_booking_attempts,
        case when total_booking_attempts > 1 then true else false end as has_multiple_attempts,
        -- ETL metadata
        created_at,
        updated_at,
        publish_time,
        -- dbt metadata for downstream auditing
        current_timestamp() as dbt_loaded_at
    from ranked_bookings
    where recency_rank = 1
)

select * from dim_carrier_bookings