{{ config(materialized='view') }}

with source as (
    SELECT * FROM {{ source('raw_data', 'cwjobs_raw' )}}
),

flatten_json as (
    SELECT DISTINCT
        value:title::String AS job_title
        , value:url::String AS url
        , value:company_name::String AS company_name
        , value:job_location::String AS location
        , value:salary::String AS salary
        , value:job_type::String AS job_type
        , value:job_description::String AS description
        , CURRENT_TIMESTAMP() as load_timestamp
        {# , case 
            when 
            listing_posted_at like '%hour%' 
                then dateadd(hour, -(regexp_replace(listing_posted_at, '[^0-9]', ''):: int) * 1, CURRENT_TIMESTAMP())
            when listing_posted_at like '%day%' 
                then dateadd(hour, -(regexp_replace(listing_posted_at, '[^0-9]', ''):: int) * 24, CURRENT_TIMESTAMP())
        end as job_listing_posted_at #}
    FROM 
        source
        , lateral flatten( input => raw_data:data)
)

SELECT 
    {{ dbt_utils.generate_surrogate_key(['job_title', 'company_name', 'location', 'F.value']) }} as jobskill_id
    , F.value AS jobskill 
    , job_title
    , company_name
    , location
    , job_type
    , salary
    , url
    , NULL as job_listing_posted_at
    , load_timestamp
FROM   
    flatten_json, 
    Table(
        Flatten(
            list_filter(
                STRTOK_TO_ARRAY(
                    TRANSLATE(REPLACE(REPLACE(description, '\n', ' '),',', ' ' ),'()[]{}.!', '        ' ), ' '
                    ),
                (select ARRAY_AGG(skill) from skills_list)
            )
        )
    ) F