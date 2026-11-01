# KPI Definitions — Banking Loan-Risk Analytics

Source table: `mart.loan_features` (one row per loan, 682 loans), exported to
`data/processed/loan_features.csv`.

Field names below are the CSV headers. Tableau shows them in title case
(for example `is_problem` appears as `Is Problem`); the Tableau formulas use
the Tableau names.

## Ground rules

1. **No single "default rate".** Finished loans (status A/B) have a final
   outcome. Running loans (C/D) are still in progress, so their problem rate is
   incomplete ("to date"). The two are always reported separately.
2. **Exposure, not loss.** The data has no interest, recoveries or costs
   (loan amount = monthly payment × duration for all 682 loans). Money figures
   are amounts at risk, never losses or profit.
3. **Every rate is shown with its loan count and a 95% Wilson interval**, so
   small groups cannot be mistaken for reliable results.
4. **Point-in-time.** Behavior features use only the 90 days strictly before
   the grant date, so they were available when the loan decision was made.
5. **Associations, not causes.** The data is observational.

---

## KPI 1 — Loan count and portfolio amount

| Item | Definition |
|---|---|
| Business question | How large is the loan portfolio, and how is it split? |
| Formula | Loans = number of loans; Portfolio amount = sum of `loan_amount` |
| Grain | Loan; aggregated to any dimension (year, region, state) |
| Tableau | `COUNTD([Loan Id])` and `SUM([Loan Amount])` |
| Limitations | Amounts are in Czech koruna (1990s), not rupees. No outstanding balance per loan exists, so this is the granted amount, not the current exposure. |
| Decision supported | Where lending is concentrated (region, size, duration). |

## KPI 2 — Problem-loan rate, finished loans (final)

| Item | Definition |
|---|---|
| Business question | Of the loans whose contract has ended, what share were not repaid? |
| Numerator | Finished loans with status B |
| Denominator | All finished loans (status A or B) |
| Baseline | 31 / 234 = 13.2% |
| Tableau | `SUM(IF [Contract State] = "Finished" THEN [Is Problem] END) / SUM(IF [Contract State] = "Finished" THEN 1 END)` |
| Limitations | Only 234 loans; finished loans were mostly granted earlier (1993–1996), so conditions may differ from recent lending. |
| Decision supported | The most reliable measure of realized credit quality. |

## KPI 3 — Problem-loan rate to date, running loans (interim)

| Item | Definition |
|---|---|
| Business question | Of the loans still running, what share are already in debt? |
| Numerator | Running loans with status D |
| Denominator | All running loans (status C or D) |
| Baseline | 45 / 448 = 10.0% |
| Tableau | `SUM(IF [Contract State] = "Running" THEN [Is Problem] END) / SUM(IF [Contract State] = "Running" THEN 1 END)` |
| Limitations | **Right-censored**: a loan granted late in 1998 has been observed for only weeks (see `months_observed`). Today's "OK so far" loans can still become problems, so this rate understates the eventual rate. Never compare it directly with KPI 2. |
| Decision supported | Early monitoring of the current book. |

## KPI 4 — Problem exposure share

| Item | Definition |
|---|---|
| Business question | What share of lent money sits in problem loans? |
| Numerator | Sum of `loan_amount` for loans with `is_problem` = 1 |
| Denominator | Sum of `loan_amount` for all loans in the group |
| Tableau | `SUM(IF [Is Problem] = 1 THEN [Loan Amount] END) / SUM([Loan Amount])` |
| Limitations | Exposure, **not loss**: no data on what was repaid before the problem or recovered afterwards. Mixes finished and running loans unless filtered by `contract_state`. |
| Decision supported | Whether risk is concentrated in larger loans (compare with KPI 2/3 counts). |

## KPI 5 — Pre-loan overdraft flag rate

| Item | Definition |
|---|---|
| Business question | How many applicants showed financial stress before the loan? |
| Numerator | Loans with `had_negative_balance_90d` = 1 (at least one negative balance in the 90 days before the grant date) |
| Denominator | All loans |
| Tableau | `SUM([Had Negative Balance 90D]) / COUNTD([Loan Id])` |
| Limitations | Only order-independent information is used (within-day order is unknown). Rare: 15 of 682 loans. |
| Decision supported | How many applications a "review if overdrawn" rule would affect. |

## KPI 6 — Early-warning precision and capture rate

| Item | Definition |
|---|---|
| Business question | When the overdraft flag fires, how often does the loan go bad, and what share of all problem loans does the flag catch? |
| Precision | Problem loans among flagged loans ÷ flagged loans (15 / 15) |
| Capture rate (recall) | Flagged problem loans ÷ all problem loans (15 / 76 ≈ 20%) |
| Lift | Precision ÷ problem rate of all loans in the same contract state |
| Tableau (precision) | `SUM(IF [Had Negative Balance 90D] = 1 THEN [Is Problem] END) / SUM([Had Negative Balance 90D])` |
| Tableau (capture) | `SUM(IF [Had Negative Balance 90D] = 1 THEN [Is Problem] END) / SUM([Is Problem])` |
| Limitations | Precision rests on 15 loans; always show it with its Wilson interval. A high-precision, low-capture flag is a review trigger, not a complete risk model. |
| Decision supported | Whether to add the flag as a manual-review rule in loan approval. |

## KPI 7 — 95% Wilson confidence interval for a rate

| Item | Definition |
|---|---|
| Purpose | Show how uncertain a rate is, given how many loans it is based on. |
| Why Wilson | The simple interval p ± 1.96·√(p(1−p)/n) breaks down for small n and for rates near 0% or 100% (it gives a zero-width interval at 15/15). The Wilson interval stays valid there. |
| Formula | p = problem loans ÷ loans, n = loans, z = 1.96 |
| Lower bound | (p + z²/2n − z·√(p(1−p)/n + z²/4n²)) ÷ (1 + z²/n) |
| Upper bound | (p + z²/2n + z·√(p(1−p)/n + z²/4n²)) ÷ (1 + z²/n) |
| Example | 15 of 15 → lower bound 1 ÷ (1 + 1.96²/15) ≈ 79.6% |

Tableau calculated fields:

```
// n
COUNTD([Loan Id])

// p
SUM([Is Problem]) / COUNTD([Loan Id])

// Wilson Lower
([p] + 1.96^2/(2*[n]) - 1.96*SQRT([p]*(1-[p])/[n] + 1.96^2/(4*[n]^2)))
/ (1 + 1.96^2/[n])

// Wilson Upper
([p] + 1.96^2/(2*[n]) + 1.96*SQRT([p]*(1-[p])/[n] + 1.96^2/(4*[n]^2)))
/ (1 + 1.96^2/[n])
```

## KPI 8 — Payment-to-credits ratio (affordability proxy)

| Item | Definition |
|---|---|
| Business question | How large is the monthly loan payment compared with the money flowing into the account? |
| Formula | `monthly_payment` ÷ (total credits in the 90 days before the grant ÷ 3) |
| Grain | Loan |
| Tableau | `AVG([Payment To Credits Ratio])`, or banded with a calculated field |
| Limitations | Credits include all money in (salary, transfers, interest), not verified income. A rough proxy, not a debt-service ratio. |
| Decision supported | Whether payment burden relative to account inflows relates to problem rates. |

---

## Known data limitations affecting KPIs

- Data covers 1993–1998 from one Czech bank; amounts in Czech koruna.
- No interest, fees on loans, recoveries or costs: no profitability KPIs.
- Owner ages below 18 at the grant date appear in the source data; shown as an
  "Under 18 (data anomaly)" band, not removed.
- About 5,300 transactions on unambiguous days do not reconcile to ± amount
  (cause unknown); features use order-independent aggregates.
- Region refers to the **branch** district of the account, not the client's
  home district.
