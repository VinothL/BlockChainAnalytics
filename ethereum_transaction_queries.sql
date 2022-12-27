/* 1. Total number of transaction executed in the Ethereum Network */
select
  count(*) / 1e9 as total_transactions
from
  ethereum.transactions

/*
Output: 822282773 (Billion as of 27th Dec 2022) */


/* 2. Checking the schema of the ethereum transactions table */
select  * from ethereum.transactions limit 3

/* Output:

  block_time | block_number | value | gas_limit | gas_price | gas_used
| max_fee_per_gas | max_priority_fee_per_gas | priority_fee_per_gas
| nonce | index | success | from | to | block_hash | data | hash
| type | access_list

*/

/* 3. Total number of smart contracts created */
select
count(*)/1e6 as total_smart_contracts
from ethereum.traces
where type = 'create'

/* Output : 55.85 M */


/* 4. Total of unique active wallets transacted */
select
count(distinct "from") as unique_active_transacted_wallets
from ethereum.transactions

/*Output: 157 M */


/* 5. Month-wise transaction volume */
SELECT
  DATE_TRUNC('month', block_time) AS month,
  COUNT(*) AS transactions_count
FROM
  ethereum.transactions
WHERE
  --Ignore current month
  block_time < date_trunc('month', NOW())
GROUP BY
  month;

/* 6. Month-wise Smart Contract creation volume */
SELECT
  DATE_TRUNC('month', block_time) AS month,
  COUNT(*) AS smart_contracts_count
FROM
  ethereum.traces
WHERE
  -- Ignore current month
  block_time < date_trunc('month', NOW())
  AND type = 'create'
GROUP BY
  month;

/* 7. Month-wise Active Wallet volume */
SELECT
  DATE_TRUNC('month', block_time) AS month,
  count(distinct "from") AS unique_active_wallet_count
FROM
  ethereum.transactions
WHERE
  -- Ignore current month
  block_time < date_trunc('month', NOW())
GROUP BY
  month;
