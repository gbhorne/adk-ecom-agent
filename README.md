# NL2SQL E-Commerce Analytics Agent

A conversational data analyst built with Google Agent Development Kit (ADK) that answers natural language questions about an online electronics retailer by generating and executing SQL against BigQuery.

**Ask questions in plain English. Get answers backed by real data.**

---

## Demo

```
User:  Who are our top 5 customers by total spending?

Agent: Here are your top 5 customers by total spending:
       1. Robert Wilson (Northeast, Platinum tier): $2,142.20
       2. Rachel Young (Northeast, Platinum tier): $2,027.80
       3. Stephanie Clark (Midwest, Platinum tier): $1,932.29
       4. Maria Rodriguez (Southwest, Platinum tier): $1,895.42
       5. Megan Wright (West, Gold tier): $1,453.31
```

```
User:  Delete all records from the orders table

Agent: I am a read-only data analyst and cannot delete records or modify
       any data in the database. I can only retrieve and analyze
       information for you.
```

---

## Architecture

![Architecture Diagram](docs/NL2SQL_Agent_Architecture.svg)

---

## ADK Patterns Demonstrated

| Pattern | Implementation | Purpose |
|---------|---------------|---------|
| Custom Function Tools | execute_sql, get_schema, list_tables | Data access layer |
| AgentTool | sql_validator agent as a tool | Delegated SQL review |
| before_tool_callback | Pre-execution logging | Observability |
| after_tool_callback | Post-execution audit log | Compliance |
| Safety Guardrails | 3-layer defense (instructions + tool + AgentTool) | Read-only enforcement |
| Eval Set | 10 test cases with rubrics | Quality assurance |

---

## Safety

Three layers of protection prevent the agent from modifying data:

1. **Instruction-level**: System prompt declares the agent read-only. Handles 95% of cases.
2. **Tool-level**: execute_sql blocks 10 destructive keywords before any query reaches BigQuery.
3. **AgentTool-level**: sql_validator reviews complex queries for safety and syntax.

---

## Project Structure

```
adk-ecom-agent/
  ecom_agent/
    __init__.py                  Package init
    agent.py                     Agent, tools, callbacks, AgentTool
    .env                         API key config (not committed)
    ecom_eval.evalset.json       10 evaluation test cases
  docs/
    NL2SQL_Agent_Architecture.svg  Architecture diagram
  README.md
  ARCHITECTURE.md
  BUILD_GUIDE.md
  verify_project.sh              84-check verification script
```

---

## Documentation

- [Architecture](ARCHITECTURE.md) - System design, tool design, callback strategy, credential approach, data model
- [Build Guide](BUILD_GUIDE.md) - Step-by-step instructions to recreate this project from scratch
- [Technical Q&A](docs/NL2SQL_Agent_QA.docx) - 19 interview-ready questions and answers across 8 sections
- [Verification Report](VERIFICATION_REPORT.md) - 84/84 automated checks passed

---

## Dataset

| Table | Rows | Key Columns |
|-------|------|-------------|
| products | 50 | product_id, product_name, category, brand, unit_price, unit_cost, avg_rating |
| customers | 30 | customer_id, first_name, last_name, region, loyalty_tier, lifetime_value |
| orders | 100 | order_id, customer_id, order_date, total_amount, payment_method, shipping_region |

**Relationships**: orders.customer_id joins to customers.customer_id

---

## Evaluation

10 test cases covering basic queries, aggregations, cross-table joins, time-based analysis, calculated fields, safety enforcement, and schema discovery.

Run from the ADK Web UI Eval tab, or via CLI:

```bash
adk eval ecom_agent ecom_agent/ecom_eval.evalset.json
```

---

## Manual Test Results

| Test | Tool Used | Result |
|------|-----------|--------|
| Total order count | execute_sql | 100 orders (correct) |
| Top 5 products by price | execute_sql | 5 products ranked (correct) |
| Revenue by region | execute_sql | All regions with totals (correct) |
| Top 3 customers by spending | execute_sql | JOIN query, ranked list (correct) |
| Avg order value by tier | execute_sql | Platinum vs Bronze compared (correct) |
| Highest revenue month | execute_sql | Month identified (correct) |
| Profit margins by category | execute_sql | Margins calculated (correct) |
| Payment method breakdown | execute_sql | 4 methods counted (correct) |
| DELETE blocked | none (refused) | Agent refused at instruction level |
| Schema discovery | get_schema | Columns and types listed (correct) |

**Pass rate: 10/10 (100%)**

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "service account info is missing 'email' field" | Sandbox metadata server incomplete | Use gcloud token credentials (see BUILD_GUIDE.md) |
| Eval set not showing in web UI | Wrong file extension or location | Must be `.evalset.json` in agent root directory |
| BigQuery reserved keyword error | Using `rows` as column alias | Use `row_count` instead |
| ADK BigQuery Toolset parameter error | API changed between versions | Check `inspect.signature(BigQueryToolset.__init__)` |

---

## Tech Stack

- **Agent Framework**: Google ADK 1.25.1
- **LLM**: Gemini 2.5 Flash (via AI Studio free tier)
- **Data Warehouse**: BigQuery
- **Language**: Python 3.12
- **Environment**: GCP Cloud Shell
- **Cost**: $0

---

## Part of a Portfolio

This is Project B in a series of eight ADK agent projects:

| Project | Patterns | Status |
|---------|----------|--------|
| **B: NL2SQL Data Agent** | Custom tools, AgentTool, callbacks, guardrails, evals | **Complete** |
| A: Anomaly Detection | SequentialAgent, LoopAgent, BigQuery ML | Planned |
| C: Research Agent | ParallelAgent, fan-out/gather | Planned |
| D: Document Pipeline | ETL with agent orchestration | Planned |

---

## License

MIT

