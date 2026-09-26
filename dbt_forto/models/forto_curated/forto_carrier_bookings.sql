{{ config(
    materialized='table'
  ) 
}}

with data_enriched as (
    select
        booking_attempt,
        carrier_booking_reference,
        id as carrier_booking_id,
        upper(trim(carrier_code)) as carrier_code,
        initcap(trim(carrier_name)) as carrier_name,
        container_types,
        cast(_etl_created_at as timestamp) as created_at,
        has_dangerous_goods,
        has_non_reefer_container,
        has_reefer_container,
        lower(trim(integration_method)) as integration_method,
        is_deleted,
        is_spot_booking,
        cast(_etl_publish_time as timestamp) as publish_time,
        shipment_id,
        `source` as carrier_booking_source,
        case when lower(trim(state)) like '%confirm%' then 'confirmed'
             when lower(trim(state)) like '%cancel%' then 'cancelled'
             when lower(trim(state)) like '%contact%' then 'contacted'
             when lower(trim(state)) = 'failed' then 'failed'
             when lower(trim(state)) = 'pending' then 'pending'
             else lower(trim(state))
        end as carrier_booking_state,
        cast(_etl_updated_at as timestamp) as updated_at
    from {{ source('forto_data_raw', 'carrier_bookings') }}
),

data_filtered as (
    select *, case when carrier_booking_state = 'confirmed' then true 
                   else false 
              end as is_volume_confirmed 
    from data_enriched
    where is_deleted = false
)

select * from data_filtered