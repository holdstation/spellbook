{{
    config(
        schema='balancer_v1_ethereum',
        alias = 'liquidity',
        
        materialized = 'incremental',
        file_format = 'delta',
        incremental_strategy = 'merge',
        unique_key = ['day', 'pool_id', 'token_address'],
        post_hook='{{ expose_spells(\'["ethereum"]\',
                                    "project",
                                    "balancer_v1",
                                    \'["stefenon", "viniabussafi"]\') }}'
    )
}}

WITH pool_labels AS (
    SELECT
        address,
        name
    FROM {{ ref('labels_balancer_v1_pools_ethereum') }}
    ),

prices AS (
        SELECT
            date_trunc('day', minute) AS day,
            contract_address AS token,
            decimals,
            AVG(price) AS price
        FROM {{ source('prices', 'usd') }}
        WHERE blockchain = 'ethereum'
        {% if is_incremental() %}
        AND minute >= date_trunc('day', now() - interval '7' day)
        {% endif %}
        GROUP BY 1, 2, 3
    ),

    cumulative_balance AS (
        SELECT
            day,
            pool,
            token,
            cumulative_amount
        FROM {{ ref('balancer_ethereum_balances') }} b
        {% if is_incremental() %}
        WHERE day >= date_trunc('day', now() - interval '7' day)
        {% endif %}
    ),
    
   cumulative_usd_balance AS (
        SELECT
            b.day,
            b.pool,
            b.token,
            t.symbol,
            cumulative_amount as token_balance_raw,
            cumulative_amount / POWER(10, COALESCE(t.decimals, p1.decimals)) AS token_balance,
            cumulative_amount / POWER(10, COALESCE(t.decimals, p1.decimals)) * COALESCE(p1.price, 0) AS protocol_liquidity_usd
        FROM cumulative_balance b
        LEFT JOIN {{ ref('tokens_ethereum_erc20') }} t ON t.contract_address = b.token
        LEFT JOIN prices p1 ON p1.day = b.day
        AND p1.token = b.token
    ),
    
    pool_liquidity_estimates AS (
        SELECT
            b.day,
            b.pool,
            SUM(b.protocol_liquidity_usd) / SUM(w.normalized_weight) AS liquidity
        FROM cumulative_usd_balance b
        INNER JOIN {{ ref('balancer_v1_ethereum_pools_tokens_weights') }} w ON b.pool = w.pool_id
        AND b.token = w.token_address
        AND CAST (b.protocol_liquidity_usd as DOUBLE) > CAST (0 as DOUBLE)
        AND CAST (w.normalized_weight as DOUBLE) > CAST (0 as DOUBLE)
        GROUP BY 1, 2
    )
    

        SELECT
            b.day,
            w.pool_id,
            w.pool_id AS pool_address,
            p.name AS pool_symbol,
            '1' AS version,
            'ethereum' AS blockchain,
            w.token_address,
            t.symbol AS token_symbol,
            token_balance_raw,
            token_balance,
            liquidity * normalized_weight AS protocol_liquidity_usd,
            liquidity * normalized_weight AS pool_liquidity_usd
        FROM pool_liquidity_estimates b
        LEFT JOIN cumulative_usd_balance c ON c.day = b.day
        AND c.pool = b.pool
        INNER JOIN {{ ref('balancer_v1_ethereum_pools_tokens_weights') }} w ON b.pool = w.pool_id
        AND w.token_address = c.token 
        AND CAST (w.normalized_weight as DOUBLE) > CAST (0 as DOUBLE)
        LEFT JOIN {{ ref('tokens_ethereum_erc20') }} t ON t.contract_address = w.token_address
        LEFT JOIN pool_labels p ON p.address = w.pool_id
