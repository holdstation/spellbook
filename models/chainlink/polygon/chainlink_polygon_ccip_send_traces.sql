{{
  config(
    
    alias='ccip_send_traces',
    materialized='view'
  )
}}

SELECT
  'polygon' as blockchain,
  block_hash,
  block_number,
  block_time,
  tx_hash,
  traces."from",
  traces."to",
  input,
  traces."output",
  traces.tx_success,
  traces.value,
  network_meta.chain_selector as chain_selector,
  network_meta.blockchain as destination
FROM
  {{ source('polygon', 'traces') }} traces
left join {{ref('chainlink_ccip_network_meta')}} network_meta on network_meta.chain_selector = bytearray_to_uint256(bytearray_substring(input, 5, 32))
WHERE
  traces."to" = (SELECT router FROM {{ref('chainlink_ccip_network_meta')}} WHERE blockchain = 'polygon')
  AND bytearray_substring(input, 1, 4) = 0x96f4e9f9