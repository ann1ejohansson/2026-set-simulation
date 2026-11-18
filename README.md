# SET simulation

> **Status:** developing code to generate data

Simulation study for SET (Systematic Error Tracing). We generate sequences of wrong answers to
single-digit multiplication items (m × n) for simulated students, where each
error has a known *true cause* (e.g. a typo, an off-by-ten error, the answer to a
neighbouring table fact). Students have a *dominant cause* that produces a
fixed share of their errors. The generated sequences are then used to test how
well SET recovers each student's dominant cause.

## Research questions

- **RQ1.** How many errors does SET need before it reliably identifies a
  student's dominant error cause?
- **RQ2.** How does recovery depend on the strength of the dominant cause
  (`p_dom`) and on how much noise is mixed into the sequence (`noise_prob`)?
- **RQ3.** Do some causes recover better than others? Causes differ in base rate
  and in how much their responses overlap with those of other causes.
- **RQ4.** How do the SET settings (window size, weighting method, `beta`)
  affect recovery?

## Project structure

```
2026-set-simulation/
├── scripts/
│   ├── cfg.R                  # settings for a run; loads packages and all functions
│   └── 01-generate-errors.R   # step 1: generate the error sequences
├── functions/
│   ├── run_cause.R            # calls one error-cause function for an item
│   ├── sample_one.R           # draws one element of a vector
│   ├── simulate_student.R     # builds one student's error sequence
│   └── error_categories/      # one function per error cause (see below)
├── tests/
│   ├── check-generated.R      # checks on the output of step 1
│   ├── error-notebook.R       # builds the interactive Error Notebook for a run
│   └── error-notebook/        # page template + built notebooks (<run>.html)
├── data/<run>/                # output of 01-generate-errors.R
└── figures/                   # 
```

## How the scripts work

### `scripts/cfg.R`: configuration

Holds every setting in one list, `cfg`, and sources all files in `functions/`.
The main settings:

| Setting            | Value                     | Meaning                 |
|--------------------|---------------------------|-------------------------|
| `causes`           | 14 error causes (or subset)                | Causes that can generate an error |
| `item_digit_range` | `1:9`                              | Items are all m × n with m, n in this range, drawn uniformly |
| `n_errors`         | 5, 10, 15, 20, 30, 50, 100         | Length of each student's error sequence |
| `p_dom`            | 0, 0.1, 0.3, 0.5, 0.7, 0.9, 1      | Chance that an error comes from the dominant cause (0 = no dominant cause) |
| `dom_causes`       | 14 error causes (or subset) | Causes used as dominant cause |
| `noise_prob`       | 0                                  | Chance that an error is noise (a random wrong answer in `noise_range`) |
| `n_students`       |                                  | Students per condition |
| `seed`             |                            | Base seed; each condition uses `seed + condition_id` |
| `window_size`, `weight_method`, `beta` | | SET settings, not used yet |

`run` names the run. Generated sequences go to
`cfg$data_dir` (`data/<run>/`) and SET output will go to `cfg$results_dir`
(`results/<run>/`). Re-running with the same `run` overwrites that run.

### `scripts/01-generate-errors.R`: generate error sequences

1. **Item × cause lookup.** For every item (m × n) and every cause, run the
   cause function to get the answers it can produce. Only *plausible* answers
   are kept: wrong, non-negative whole numbers. Combinations with no plausible
   answer are dropped, so each cause can only be drawn on items where it can
   actually produce an error.
2. **Base rates.** For each cause, count how many answers it can produce over
   all items, divided by the number of distinct wrong answers over all items.
   Causes overlap, so these rates do not sum to 1; they are normalised into
   sampling probabilities (`cause_probs`).
3. **Conditions.** Full factorial of `n_errors × p_dom × dom_cause × noise_prob`.
   With `p_dom = 0` the dominant cause is irrelevant, so there is one baseline
   condition per `n_errors`. With the current settings this gives 595 conditions.
4. **Simulation.** For each condition and student, `simulate_student()`
   generates every error item first:
   1. draw an item (uniformly);
   2. with probability `noise_prob`: noise (a random wrong answer);
   3. otherwise, with probability `p_dom`: the dominant cause, **if it can
      produce an error on that item**;
   4. otherwise: a cause drawn from the base rates of the causes that can
      produce an error on that item, renormalised;
   5. draw one of that cause's plausible answers on the item.

   Four causes cannot produce an error on every item (`m_div_n` 14 of 81
   items, `m_minus_n` 45, `reverse` 50, `m_plus_n` 80). Drawing the item first
   keeps items spread the same for every student, whatever their dominant
   cause. As a result, `p_dom` is the chance of the dominant error *when the
   item allows it*, and the realised dominant share for these four causes is
   lower than `p_dom` (e.g. about 16% for `m_div_n` at `p_dom = 0.9`).
5. **Expected shares.** For each condition, the expected share of every true
   cause under this model, saved for the checks and the notebook.

**Output** (`data/<run>/`):

| File | Contents |
|------|----------|
| `cNNN_nNNN_pdomX.XX_<cause>_noiseX.XX.rds` | One file per condition: one row per error, with `student_id`, `error_index`, `true_cause`, `dom_cause`, `m`, `n`, `correct`, `response` and the condition settings |
| `conditions.rds` / `.csv` | One row per condition: id, seed, file name, settings |
| `cause_responses.rds` | Item × cause lookup with all plausible answers |
| `base_rate_theoretical.rds` | Theoretical base rate per cause |
| `cause_probs.rds` | Normalised sampling probabilities per cause |
| `expected_shares.rds` | Expected share of each true cause per condition under this sampling model (used by the checks and the notebook) |

### `tests/check-generated.R`: checks on generated data

Run after step 1. Sources `cfg.R` and reads the run in `cfg$data_dir` (change
`run` in `cfg.R` to check another run). To check another folder, set
`check_dir` first, e.g. `check_dir <- "data/some-other-run"`. It:

1. prints the first condition for a look by hand;
2. checks per condition that the number of rows is right, no answer is correct,
   every response can be produced by its true cause on that item, and
   `dom_cause` matches the condition (returns an empty table if all is fine);
3. compares the realised cause shares in the baseline conditions with the
   expected shares in `expected_shares.rds`;
4. per student, compares the expected share of dominant-cause errors with the
   share actually caused by it, the share of responses that *fit* it, and the
   share that fit *only* it, as a measure of how ambiguous the errors are.

### `tests/error-notebook.R`: Error Notebook

Builds an interactive HTML page for the run set in `cfg.R`, writes it to
`tests/error-notebook/<run>.html` and opens it in the browser. Choose a
condition (`n_errors`, `p_dom`, dominant cause, `noise_prob`) and a student to
see their sequence of wrong answers. For each error the page shows the true
cause and every other cause that could have produced the same answer. It also
shows where the errors fell in the 9 × 9 item pool, the count per true cause
against the expected count, and the running share of the dominant cause. A
slider and Replay button step through the sequence one error at a time.
The page template is `tests/error-notebook/template.html`; the script fills in
the run's data.

## Error causes

Each file in `functions/error_categories/` takes an item (m, n) and returns the
answers the cause can produce.

| Cause | Answer produced |
|-------|-----------------|
| `operator_relevant` | Any other product from the times tables (digits in `item_digit_range`) |
| `operand_related` | Product with one operand 1 or 2 higher/lower (e.g. 7 × 8 → 48, 63) |
| `double_half` | Correct answer × 2 or ÷ 2 |
| `different_unit` | Same tens, different unit (e.g. 56 → 50–59) |
| `miss_1` / `miss_10` / `miss_100` | Correct answer ± 1 / 10 / 100 |
| `miss_power` | Correct answer × or ÷ a power of ten (10 to 10⁵) |
| `m_div_n` / `m_minus_n` / `m_plus_n` | m ÷ n, m − n, m + n |
| `typo` | A digit left out or repeated |
| `reverse` | Digits reversed (not for one-digit answers or answers ending in 0) |
| `zero` | 0 |

## Running the simulation

Run everything from the `2026-set-simulation/` folder. Both scripts source `scripts/cfg.R`
themselves.

```r
source("scripts/01-generate-errors.R")
source("tests/check-generated.R")
source("tests/error-notebook.R")   # optional: open the Error Notebook
```

Requires R, the `tidyverse` and `jsonlite`.

## Next steps

- Step 2: run SET on the generated sequences over `window_size`,
  `weight_method` and `beta`.
- Evaluate recovery of the dominant cause per condition.
- Figures.
