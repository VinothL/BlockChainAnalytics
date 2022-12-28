/* 1. When did Ethereum reach all time high in terms of mining difficulty? */
SELECT
  DATE_TRUNC('day', `time`) as day,
  AVG(difficulty) as avg_difficulty
FROM
  ethereum.blocks
GROUP BY day


/* 2. When did the beacon chain go live? */
/* Deposit address : 0x00000000219ab540356cBB839Cbe05303d7705Fa */
WITH eth_deposit_status AS (
    SELECT block_time,
           SUM(value/1e18) OVER (ORDER by block_time) AS total_eth_deposited
    FROM  ethereum.traces
    WHERE `to` = LOWER('0x00000000219ab540356cBB839Cbe05303d7705Fa') --the deposit contract address
      AND success = true
      AND value > 0
)
SELECT DATE(MIN(block_time)) AS genesis_trigger_date,
       DATE(MIN(block_time + INTERVAL '7 DAY')) AS beacon_chain_launch_date
FROM eth_deposit_status
where total_eth_deposited >= 524288 -- 25% of the last

/* 3. Find out the total ETH deposited so far */
SELECT
sum(value)/1e18 as total_eth_deposited
FROM ethereum.traces
WHERE `to` = LOWER('0x00000000219ab540356cBB839Cbe05303d7705Fa')
AND success = true
AND value > 0

/* 4. Find out the Unique depositors */
SELECT count(distinct "from") as unique_depositors
FROM ethereum.traces
WHERE  `to` = LOWER('0x00000000219ab540356cBB839Cbe05303d7705Fa')
AND success = true
AND block_time >= '2020-10-01'


/* 5. Which entity has the highest stake percentage? */
WITH depositors AS (
    SELECT "from" AS depositor,
           SUM(value) / 1e18 AS eth_deposited
    FROM ethereum.traces tr
    WHERE `to` = LOWER('0x00000000219ab540356cBB839Cbe05303d7705Fa') --eth2 deposit contract address
    AND success = true
    AND value > 0
    AND block_time >= '2020-10-01'
    GROUP BY depositor
  )
SELECT
    d.depositor,
    '<a href=https://etherscan.io/address/' || d.depositor || ' target=_blank>EtherScan</a>' as etherscan_link,
    (eth_deposited * 100)/total_eth_deposited as perct_stake
FROM depositors d JOIN
  (select sum(eth_deposited) as total_eth_deposited from depositors) s
  on 1=1
ORDER BY eth_deposited DESC


/* 6. Daily ETH issuance rate post the merge */
WITH block_rewards AS (
    SELECT
        date_trunc('day',block_time) AS day,
        SUM(value/1e18) as block_reward
    FROM ethereum.traces
    WHERE
     "type" = 'reward'
    AND block_time >= '2022-08-01' --fetch data from Aug'22
    AND block_number < 15537393  --PoW rewards are issued pre-merge
    GROUP BY day ),
fees_burnt AS (
    SELECT DATE_TRUNC('day',`time`) as day ,
    sum(gas_used * base_fee_per_gas) / 1e18 as fees_burnt
    FROM ethereum.blocks
    WHERE `time` >= '2022-08-01'
    GROUP BY day),
eth_validators_daily AS (
    SELECT
      DATE_TRUNC('day', block_time) AS day,
      SUM(value) / 1e18 / 32 AS num_validators
    FROM
      ethereum.traces
    WHERE
      `to` = LOWER('0x00000000219ab540356cBB839Cbe05303d7705Fa') --eth2 deposit contract address
      AND success = true
      AND value > 0
    GROUP BY
      day
),
 eth_validators AS (
    SELECT
        day,
        num_validators,
        SUM(num_validators) OVER (ORDER by day) AS total_validators
    FROM eth_validators_daily
 ),
 eth_issuance_pos AS (
    SELECT
        day,
        225 * 32 * 64 * total_validators / SQRT(32 * 1e9 * total_validators) as estimated_maxeth_issued_pos
    FROM eth_validators
    WHERE day >= '2022-08-01'
 )
SELECT
    ev.day,
    estimated_maxeth_issued_pos AS estimated_maxeth_issued_pos,
    COALESCE(block_reward,0) AS block_reward,
    COALESCE(fees_burnt,0) as eth_burnt,
    (estimated_maxeth_issued_pos + block_reward - fees_burnt) as net_issuance
FROM eth_issuance_pos ev
LEFT JOIN fees_burnt fb
    ON ev.day = fb.day
LEFT join block_rewards br
    ON ev.day = br.day
