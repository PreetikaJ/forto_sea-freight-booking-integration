{{ config(
    materialized='table'
  ) 
}}

with shipments_base as (
    select * from {{ source('forto_curated', 'forto_shipments') }}
),

dim_carrier_bookings as (
    select * from {{ ref('dim_carrier_bookings') }}
),

-- Join shipments with the new dimensional table.
-- For shipments that appear in dim_carrier_bookings (new product feature),
-- use the is_confirmed_volume flag derived from carrier booking state.
-- For all other shipments, retain the original is_confirmed_volume from shipments.
enriched as (
    select
        s.house_shipment_id,
        s.shipment_id,
        s.shipment_status,
        s.booking_id,
        s.booking_number,
        s.transport_mode,
        s.transport_type,
        s.trade_class,
        s.incoterms,
        s.chargeable_weight,
        s.chargeable_cbm,
        s.teu,
        s.departure_date,
        s.canceled_at,
        s.created_at,
        s.updated_at,
        -- Unified is_confirmed_volume flag:
        -- Priority: dim_carrier_bookings (new integration) > shipments (legacy)
        -- This ensures KPI consistency: only confirmed bookings count towards volume.
        case
            when dcb.shipment_id is not null then dcb.is_volume_confirmed
            when s.is_confirmed_volume = true then true
            when s.is_confirmed_volume = false then false
            else false  -- Default to false for unconfirmed/unset records
        end as is_confirmed_volume,
        -- Source tracking for auditability and reconciliation
        case
            when dcb.shipment_id is not null then 'carrier_bookings_integration'
            when s.is_confirmed_volume is not null then 'shipments_legacy'
            else 'not_applicable'
        end as confirmed_volume_source,
        -- Carrier booking enrichment (only for shipments using new integration)
        dcb.carrier_code,
        dcb.carrier_name,
        dcb.carrier_booking_state,
        dcb.carrier_booking_reference,
        dcb.integration_method,
        dcb.total_booking_attempts,
        dcb.has_multiple_attempts,
        -- Volume measures (only count when confirmed)
        case
            when case
                when dcb.shipment_id is not null then dcb.is_volume_confirmed
                when s.is_confirmed_volume = true then true
                else false
            end = true
            then coalesce(s.teu, 0)
            else 0
        end as confirmed_teu,
        case
            when case
                when dcb.shipment_id is not null then dcb.is_volume_confirmed
                when s.is_confirmed_volume = true then true
                else false
            end = true
            then coalesce(s.chargeable_weight, 0)
            else 0
        end as confirmed_chargeable_weight,
        case
            when case
                when dcb.shipment_id is not null then dcb.is_volume_confirmed
                when s.is_confirmed_volume = true then true
                else false
            end = true
            then coalesce(s.chargeable_cbm, 0)
            else 0
        end as confirmed_chargeable_cbm,
        s.publish_time
    from shipments_base s
    left join dim_carrier_bookings dcb on s.shipment_id = dcb.shipment_id
)

select * from enriched