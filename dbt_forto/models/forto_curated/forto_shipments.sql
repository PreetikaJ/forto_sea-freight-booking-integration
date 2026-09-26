{{ config(
    materialized='table'
  ) 
}}

with data_enriched as (
    select
        house_shipment_id,
        shipment_id,
        status as shipment_status,
        booking_id,
        booking_number,
        carrier_booking_status,
        transport_mode,
        transport_type,
        trade_class,
        incoterms,
        chargeable_weight,
        chargeable_cbm,
        teu,
        departure_date,
        canceled_at,
        is_confirmed_volume,
        cast(created_at as timestamp) as created_at,
        cast(updated_at as timestamp) as updated_at,
        cast(_etl_publish_time as timestamp) as publish_time
    from {{ source('forto_data_raw', 'shipments') }}
)

select * from data_enriched