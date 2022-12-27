/* 1. Can you find the profitable month for the miners in transaction fees?
Divided by 1e9 to convert gas_price to gwei and again by 1e9 to convert gwei to eth
Divided by 1e6 to report the results in millions
*/
SELECT
  DATE_TRUNC('month', block_time) AS month,
  SUM(gas_used * gas_price/1e18) AS gas_fees_in_eth
FROM
  ethereum.transactions
WHERE
  block_number < 12965000
  -- After this block, Miners receive only part of the transaction fees.
  group by month


/* 2. Latest block's gas limit and usage */
SELECT
  number as block_number,
  gas_used AS gas_used,
  -- gas used by all transactions in that block
  gas_limit - gas_used AS gas_remaining
FROM
  ethereum.blocks
ORDER by
    block_number DESC
LIMIT 10;

/* 3. When did the gas limit increased to 3M */
SELECT
    DATE_TRUNC('day', time) AS block_date,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gas_limit) AS median_gas_limit
FROM
  ethereum.blocks
GROUP BY
  block_date

/* 4. Can you list min and max gas price (in gwei) paid in the block# 12465199? */
SELECT
     MIN(gas_price) / 1e9 as min_gas_price_gwei
   , MAX(gas_price) / 1e9 as max_gas_price_gwei

FROM
    ethereum.transactions
WHERE
   block_number = 2465199

/* 5. When did the EIP-1559 adopted by the users i.e. EIP-1559 % of total transaction */
SELECT
  DATE_TRUNC('month',block_time) AS month,
  -- For every month, Compute Number of eip 1559 transactions / Total transactions
  (COUNT(*) FILTER ( WHERE type = 'DynamicFee') * 100) / COUNT(*) AS eip1559_tx,
  (COUNT(*) FILTER ( WHERE type = 'Legacy' ) * 100) / COUNT(*) AS legacy_tx,
  (COUNT(*) FILTER ( WHERE type NOT IN ('DynamicFee', 'Legacy')) * 100) / COUNT(*) AS other_tx
FROM
  ethereum.transactions
WHERE
  block_number >= 12965000 --London upgrade block number
GROUP BY
  month

/* 6. Monthwise Gas price split  */
  SELECT
    DATE_TRUNC('month', tx.block_time) AS month,
     --before london upgrade, all gas fees went to the miner
     --after london upgrade, only the priority fees goes to the miner
    SUM(
      CASE
        WHEN tx.block_number < 12965000 THEN tx.gas_used * tx.gas_price/1e18
        ELSE tx.gas_used * tx.priority_fee_per_gas/1e18
      END
    ) as fees_miner_eth,
    SUM(tx.gas_used * blk.base_fee_per_gas/1e18) AS fees_burnt_eth
  FROM
    ethereum.transactions tx
    INNER JOIN ethereum.blocks blk ON tx.block_number = blk.number
  WHERE
    tx.block_time >= '2021-01-01'
  GROUP BY
    month;

/* 7. To understand gas fee volatality post the E1559 */
--Compute the IQR for every block since 2021
WITH blocks_iqr_gas AS (
    SELECT
    block_number,
    ((PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY gas_price)) - (PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY gas_price))) / ((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gas_price)) + 0.0000000000000000001) AS iqr_gas
    FROM ethereum.transactions
    WHERE DATE(block_time)>= '2021-01-01'
    GROUP BY block_number
)
--Compute the median of IQR for every month
SELECT DATE_TRUNC('month', time) AS month,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY iqr_gas) AS median_gas_volatility
FROM blocks_iqr_gas blk_iqr
INNER JOIN ethereum.blocks blk
ON blk_iqr.block_number = blk.number
GROUP BY month;


/* 8. Transactions failed due to Out of Gas in the last one hour limit 10 */

SELECT
  block_number,
  tx_hash,
  error,
  'https://etherscan.io/tx/' || tx_hash AS etherscan_tx_link,
  'https://etherscan.io/vmtrace?txhash=' || tx_hash || '&type=gethtrace2' AS etherscan_trace_link
FROM
  ethereum.traces
WHERE error = 'Out of gas'
  AND block_time > NOW() - INTERVAL '1 hour'
ORDER BY
  block_time DESC
LIMIT
  10;


/* 9. What was the maximum gas price paid in the month of Aug'22 for a (out-of-gas)  failed transaction? */
SELECT
  max(tx.gas_used * tx.gas_price) / 1e18 AS max_gas_fees_in_eth
FROM
  ethereum.transactions tx
  INNER JOIN ethereum.traces tr ON tx.hash = tr.tx_hash
WHERE
  error = 'Out of gas'
  AND DATE_TRUNC('month', tx.block_time) = '2022-08-01'
  AND DATE_TRUNC('month', tr.block_time) = '2022-08-01'
