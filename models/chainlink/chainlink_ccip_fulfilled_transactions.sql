{{
  config(
    
    alias='ccip_fulfilled_transactions',
    post_hook='{{ expose_spells(\'["arbitrum", "avalanche_c", "base", "bnb", "ethereum", "optimism", "polygon"]\',
                            "project",
                            "chainlink",
                            \'["linkpool_jon"]\') }}'
  )
}}

{% set models = [
  'chainlink_arbitrum_ccip_fulfilled_transactions',
  'chainlink_avalanche_c_ccip_fulfilled_transactions',
  'chainlink_base_ccip_fulfilled_transactions',
  'chainlink_bnb_ccip_fulfilled_transactions',
  'chainlink_ethereum_ccip_fulfilled_transactions',
  'chainlink_optimism_ccip_fulfilled_transactions',
  'chainlink_polygon_ccip_fulfilled_transactions'
] %}

SELECT *
FROM (
    {% for model in models %}
    SELECT
      blockchain,
      block_time,
      date_month,
      node_address,
      token_amount,
      usd_amount,
      tx_hash,
      tx_index
    FROM {{ ref(model) }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
)